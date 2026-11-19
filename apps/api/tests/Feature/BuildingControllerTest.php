<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

class BuildingControllerTest extends TestCase
{
    use RefreshDatabase;

    private function organization(string $name = 'North'): string
    {
        $id = (string) Str::uuid();
        DB::table('organizations')->insert([
            'id' => $id, 'name' => $name, 'slug' => $id, 'timezone' => 'UTC',
        ]);

        return $id;
    }

    private function member(string $organization, string $role, bool $active = true): User
    {
        $user = User::factory()->create();
        DB::table('organization_memberships')->insert([
            'id' => (string) Str::uuid(), 'organization_id' => $organization,
            'user_id' => $user->id, 'role' => $role, 'active' => $active,
        ]);

        return $user;
    }

    private function authenticate(User $user): string
    {
        $token = $user->createToken('building-test')->plainTextToken;
        $this->withToken($token);

        return $token;
    }

    private function building(string $organization, string $code = 'B-001'): string
    {
        $id = (string) Str::uuid();
        DB::table('buildings')->insert([
            'id' => $id, 'organization_id' => $organization, 'name' => 'Office',
            'code' => $code, 'address' => null, 'timezone' => 'Europe/Paris',
            'created_at' => now(), 'updated_at' => now(),
        ]);

        return $id;
    }

    private function payload(string $code = 'B-001'): array
    {
        return ['name' => 'Office', 'code' => $code,
            'address' => '1 Example Street', 'timezone' => 'Europe/Paris'];
    }

    public function test_new_permission_mapping_preserves_existing_permissions(): void
    {
        foreach (['viewer', 'operator', 'admin', 'owner'] as $role) {
            $this->assertDatabaseHas('role_permissions', [
                'role_code' => $role, 'permission_code' => 'buildings.view',
            ]);
            $this->assertSame(in_array($role, ['admin', 'owner'], true),
                DB::table('role_permissions')->where('role_code', $role)
                    ->where('permission_code', 'buildings.manage')->exists());
        }
        $this->assertDatabaseHas('role_permissions', [
            'role_code' => 'owner', 'permission_code' => 'roles.manage',
        ]);
    }

    public function test_permission_migration_rolls_back_only_building_permissions(): void
    {
        $migration = require database_path('migrations/2026_11_19_000001_add_building_permissions.php');
        $migration->down();
        $this->assertDatabaseMissing('permissions', ['code' => 'buildings.view']);
        $this->assertDatabaseMissing('permissions', ['code' => 'buildings.manage']);
        $this->assertDatabaseHas('role_permissions', [
            'role_code' => 'owner', 'permission_code' => 'roles.manage',
        ]);
        $migration->up();
        $this->assertDatabaseHas('role_permissions', [
            'role_code' => 'viewer', 'permission_code' => 'buildings.view',
        ]);
    }

    public function test_unauthenticated_expired_revoked_and_inactive_accounts_are_denied(): void
    {
        $organization = $this->organization();
        $url = "/api/v1/organizations/$organization/buildings";
        $this->getJson($url)->assertUnauthorized();
        $this->get($url)->assertUnauthorized()->assertJsonPath('message', 'Unauthenticated.');
        $this->postJson($url, $this->payload())->assertUnauthorized();
        $this->getJson("$url/".Str::uuid())->assertUnauthorized();
        $this->patchJson("$url/".Str::uuid(), ['name' => 'X'])->assertUnauthorized();

        $user = $this->member($organization, 'owner');
        $expired = $user->createToken('expired', ['*'], now()->addMinute())->plainTextToken;
        $this->travel(2)->minutes();
        $this->withToken($expired)->getJson($url)->assertUnauthorized();
        $this->travelBack();
        $revoked = $user->createToken('revoked');
        $revoked->accessToken->delete();
        Auth::forgetGuards();
        $this->withToken($revoked->plainTextToken)->getJson($url)->assertUnauthorized();
        DB::table('users')->where('id', $user->id)->update(['is_active' => false]);
        Auth::forgetGuards();
        $this->withToken($user->createToken('disabled')->plainTextToken)
            ->getJson($url)->assertUnauthorized();
    }

    public function test_inactive_membership_and_foreign_organization_return_404(): void
    {
        $own = $this->organization();
        $foreign = $this->organization('South');
        $user = $this->member($own, 'owner');
        $this->member($foreign, 'viewer');
        $foreignBuilding = $this->building($foreign);
        $this->authenticate($user);

        $this->getJson("/api/v1/organizations/$foreign/buildings")->assertNotFound();
        $this->postJson("/api/v1/organizations/$foreign/buildings", $this->payload())
            ->assertNotFound();
        $this->getJson("/api/v1/organizations/$own/buildings/$foreignBuilding")
            ->assertNotFound();
        $this->patchJson("/api/v1/organizations/$own/buildings/$foreignBuilding", ['name' => 'Changed'])
            ->assertNotFound();
        $this->assertDatabaseHas('buildings', ['id' => $foreignBuilding, 'name' => 'Office']);

        DB::table('organization_memberships')->where('user_id', $user->id)->update(['active' => false]);
        $this->getJson("/api/v1/organizations/$own/buildings")->assertNotFound();
    }

    public function test_each_role_can_view_but_only_admin_and_owner_can_manage(): void
    {
        $organization = $this->organization();
        $building = $this->building($organization);
        foreach (['viewer', 'operator', 'admin', 'owner'] as $role) {
            $user = $this->member($organization, $role);
            $this->authenticate($user);
            $base = "/api/v1/organizations/$organization/buildings";
            $listed = $this->getJson($base)->assertOk();
            $this->assertContains($building, array_column($listed->json('data'), 'id'));
            $this->getJson("$base/$building")->assertOk()->assertJsonPath('data.id', $building);
            if (in_array($role, ['admin', 'owner'], true)) {
                $this->postJson($base, $this->payload(strtoupper($role)))->assertCreated();
                $this->patchJson("$base/$building", ['name' => "Office $role"])->assertOk();
            } else {
                $this->postJson($base, $this->payload(strtoupper($role)))->assertForbidden();
                $this->patchJson("$base/$building", ['name' => 'Forbidden'])->assertForbidden();
            }
            Auth::forgetGuards();
        }
    }

    public function test_active_member_without_view_permission_receives_403(): void
    {
        $organization = $this->organization();
        $viewer = $this->member($organization, 'viewer');
        $building = $this->building($organization);
        DB::table('role_permissions')->where('role_code', 'viewer')
            ->where('permission_code', 'buildings.view')->delete();
        $this->authenticate($viewer);

        $this->getJson("/api/v1/organizations/$organization/buildings")->assertForbidden();
        $this->getJson("/api/v1/organizations/$organization/buildings/$building")
            ->assertForbidden();
    }

    public function test_listing_is_paginated_stable_and_tenant_scoped(): void
    {
        $own = $this->organization();
        $foreign = $this->organization('South');
        $viewer = $this->member($own, 'viewer');
        $this->building($foreign, 'F-001');
        $this->building($own, 'C-003');
        $this->building($own, 'A-001');
        $this->building($own, 'B-002');
        $this->authenticate($viewer);

        $base = "/api/v1/organizations/$own/buildings";
        $this->getJson("$base?per_page=2")->assertOk()->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.code', 'A-001')->assertJsonPath('meta.total', 3)
            ->assertJsonPath('meta.last_page', 2);
        $this->getJson("$base?per_page=2&page=2")->assertOk()
            ->assertJsonPath('data.0.code', 'C-003')->assertJsonPath('meta.current_page', 2);
        $this->getJson("$base?per_page=101")->assertUnprocessable();
        $this->getJson("$base?page=0")->assertUnprocessable();
    }

    public function test_creation_uses_server_tenant_uuid_and_appends_audit_event(): void
    {
        $organization = $this->organization();
        $admin = $this->member($organization, 'admin');
        $this->authenticate($admin);

        $response = $this->postJson("/api/v1/organizations/$organization/buildings", $this->payload())
            ->assertCreated()->assertJsonPath('data.organization_id', $organization)
            ->assertJsonPath('data.code', 'B-001')
            ->assertJsonStructure(['data' => [
                'id', 'organization_id', 'name', 'code', 'address', 'timezone',
                'created_at', 'updated_at',
            ]]);
        $id = $response->json('data.id');
        $this->assertTrue(Str::isUuid($id));
        $this->assertDatabaseHas('buildings', ['id' => $id, 'organization_id' => $organization]);
        $this->assertDatabaseHas('audit_events', [
            'organization_id' => $organization, 'actor_user_id' => $admin->id,
            'action' => 'building.created', 'subject_type' => 'building', 'subject_id' => $id,
        ]);
    }

    public function test_update_changes_only_allowed_fields_and_appends_audit_event(): void
    {
        $organization = $this->organization();
        $owner = $this->member($organization, 'owner');
        $building = $this->building($organization);
        $this->authenticate($owner);

        $this->patchJson("/api/v1/organizations/$organization/buildings/$building", [
            'name' => 'Updated Office', 'address' => null, 'timezone' => 'UTC',
        ])->assertOk()->assertJsonPath('data.id', $building)
            ->assertJsonPath('data.name', 'Updated Office')
            ->assertJsonPath('data.address', null);
        $this->assertDatabaseHas('buildings', [
            'id' => $building, 'code' => 'B-001', 'organization_id' => $organization,
            'timezone' => 'UTC',
        ]);
        $this->assertDatabaseHas('audit_events', [
            'organization_id' => $organization, 'actor_user_id' => $owner->id,
            'action' => 'building.updated', 'subject_type' => 'building', 'subject_id' => $building,
        ]);
    }

    public function test_duplicate_code_is_scoped_to_organization(): void
    {
        $own = $this->organization();
        $foreign = $this->organization('South');
        $owner = $this->member($own, 'owner');
        $this->building($own, 'B-001');
        $this->building($foreign, 'B-001');
        $this->authenticate($owner);

        $this->postJson("/api/v1/organizations/$own/buildings", $this->payload('B-001'))
            ->assertUnprocessable()->assertJsonValidationErrors('code');
        $this->postJson("/api/v1/organizations/$own/buildings", $this->payload('B-002'))
            ->assertCreated();
        $this->assertDatabaseCount('buildings', 3);

        $foreignOwner = $this->member($foreign, 'owner');
        Auth::forgetGuards();
        $this->authenticate($foreignOwner);
        $this->postJson("/api/v1/organizations/$foreign/buildings", $this->payload('B-002'))
            ->assertCreated();
        $this->assertDatabaseCount('buildings', 4);
        Auth::forgetGuards();
    }

    public function test_validation_and_foreign_organization_injection_fail_without_audit(): void
    {
        $own = $this->organization();
        $foreign = $this->organization('South');
        $owner = $this->member($own, 'owner');
        $building = $this->building($own);
        $this->authenticate($owner);
        $base = "/api/v1/organizations/$own/buildings";

        $this->postJson($base, ['name' => '', 'code' => 'bad code',
            'address' => str_repeat('x', 256), 'timezone' => 'Not/AZone'])
            ->assertUnprocessable()->assertJsonValidationErrors(['name', 'code', 'address', 'timezone']);
        $this->postJson($base, [...$this->payload('B-002'), 'organization_id' => $foreign])
            ->assertUnprocessable()->assertJsonValidationErrors('organization_id');
        $this->patchJson("$base/$building", ['organization_id' => $foreign])
            ->assertUnprocessable()->assertJsonValidationErrors('organization_id');
        $this->patchJson("$base/$building", [])->assertUnprocessable();
        $this->assertDatabaseHas('buildings', ['id' => $building, 'organization_id' => $own]);
        $this->assertDatabaseMissing('audit_events', ['action' => 'building.created']);
        $this->assertDatabaseMissing('audit_events', ['action' => 'building.updated']);
    }

    public function test_update_rejects_duplicate_code_within_the_same_organization(): void
    {
        $organization = $this->organization();
        $owner = $this->member($organization, 'owner');
        $first = $this->building($organization, 'B-001');
        $second = $this->building($organization, 'B-002');
        $this->authenticate($owner);

        $base = "/api/v1/organizations/$organization/buildings";
        $this->patchJson("$base/$second", ['code' => 'B-001'])
            ->assertUnprocessable()->assertJsonValidationErrors('code');
        $this->patchJson("$base/$first", ['code' => 'B-001'])->assertOk();
        $this->assertDatabaseHas('buildings', ['id' => $second, 'code' => 'B-002']);
    }

    public function test_delete_route_is_not_exposed(): void
    {
        $organization = $this->organization();
        $owner = $this->member($organization, 'owner');
        $building = $this->building($organization);
        $this->authenticate($owner);

        $this->deleteJson("/api/v1/organizations/$organization/buildings/$building")
            ->assertStatus(405);
        $this->assertDatabaseHas('buildings', ['id' => $building]);
    }
}
