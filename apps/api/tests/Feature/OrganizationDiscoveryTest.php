<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

class OrganizationDiscoveryTest extends TestCase
{
    use RefreshDatabase;

    private function organization(string $name): string
    {
        $id = (string) Str::uuid();
        DB::table('organizations')->insert([
            'id' => $id, 'name' => $name, 'slug' => Str::slug($name).'-'.$id,
            'timezone' => 'UTC',
        ]);

        return $id;
    }

    private function membership(User $user, string $organizationId, string $role, bool $active = true): string
    {
        $id = (string) Str::uuid();
        DB::table('organization_memberships')->insert([
            'id' => $id, 'organization_id' => $organizationId,
            'user_id' => $user->id, 'role' => $role, 'active' => $active,
            'created_at' => now(), 'updated_at' => now(),
        ]);

        return $id;
    }

    public function test_unauthenticated_and_invalid_bearer_requests_are_rejected(): void
    {
        $this->getJson('/api/v1/auth/organizations')->assertUnauthorized();
        $this->withToken('invalid-token')->getJson('/api/v1/auth/organizations')->assertUnauthorized();
    }

    public function test_plain_api_requests_without_json_accept_header_return_401(): void
    {
        $this->get('/api/v1/auth/organizations')->assertUnauthorized()
            ->assertJsonPath('message', 'Unauthenticated.');
        $this->get('/api/v1/auth/me')->assertUnauthorized()
            ->assertJsonPath('message', 'Unauthenticated.');
    }

    public function test_expired_and_revoked_tokens_are_rejected(): void
    {
        $user = User::factory()->create();
        $expired = $user->createToken('expired', ['*'], now()->addMinute())->plainTextToken;
        $this->travel(2)->minutes();
        $this->withToken($expired)->getJson('/api/v1/auth/organizations')->assertUnauthorized();

        $activeToken = $user->createToken('active');
        $activeToken->accessToken->delete();
        Auth::forgetGuards();
        $this->withToken($activeToken->plainTextToken)->getJson('/api/v1/auth/organizations')->assertUnauthorized();
    }

    public function test_disabled_user_and_web_session_are_rejected(): void
    {
        $user = User::factory()->create();
        $token = $user->createToken('active')->plainTextToken;
        DB::table('users')->where('id', $user->id)->update(['is_active' => false]);

        $this->withToken($token)->getJson('/api/v1/auth/organizations')->assertUnauthorized();
        Auth::forgetGuards();
        $this->actingAs($user)->getJson('/api/v1/auth/organizations')->assertUnauthorized();
    }

    public function test_user_without_memberships_gets_an_empty_list(): void
    {
        $user = User::factory()->create();
        $token = $user->createToken('active')->plainTextToken;

        $this->withToken($token)->getJson('/api/v1/auth/organizations')
            ->assertOk()->assertExactJson(['data' => []]);
    }

    public function test_single_membership_returns_only_minimal_server_derived_data(): void
    {
        $user = User::factory()->create();
        $organizationId = $this->organization('North Campus');
        $this->membership($user, $organizationId, 'owner');
        $token = $user->createToken('active')->plainTextToken;

        $this->withToken($token)->getJson('/api/v1/auth/organizations?role=viewer')
            ->assertOk()->assertExactJson(['data' => [[
                'id' => $organizationId,
                'name' => 'North Campus',
                'role' => 'owner',
                'permissions' => ['buildings.manage', 'buildings.view', 'equipment.manage', 'equipment.view', 'floors.manage', 'floors.view', 'roles.manage', 'users.manage', 'users.view', 'zones.manage', 'zones.view'],
            ]]]);
    }

    public function test_multiple_memberships_include_every_role_with_current_permissions(): void
    {
        $user = User::factory()->create();
        $organizations = [];
        foreach (['viewer', 'operator', 'admin', 'owner'] as $role) {
            $organizationId = $this->organization(ucfirst($role));
            $this->membership($user, $organizationId, $role);
            $organizations[$role] = $organizationId;
        }
        $token = $user->createToken('active')->plainTextToken;

        $response = $this->withToken($token)->getJson('/api/v1/auth/organizations')->assertOk()->assertJsonCount(4, 'data');
        $byRole = collect($response->json('data'))->keyBy('role');
        $this->assertSame(['buildings.view', 'equipment.view', 'floors.view', 'zones.view'], $byRole['viewer']['permissions']);
        $this->assertSame(['buildings.view', 'equipment.view', 'floors.view', 'zones.view'], $byRole['operator']['permissions']);
        $this->assertSame(['buildings.manage', 'buildings.view', 'equipment.manage', 'equipment.view', 'floors.manage', 'floors.view', 'users.manage', 'users.view', 'zones.manage', 'zones.view'], $byRole['admin']['permissions']);
        $this->assertSame(['buildings.manage', 'buildings.view', 'equipment.manage', 'equipment.view', 'floors.manage', 'floors.view', 'roles.manage', 'users.manage', 'users.view', 'zones.manage', 'zones.view'], $byRole['owner']['permissions']);
        foreach ($organizations as $role => $id) {
            $this->assertSame($id, $byRole[$role]['id']);
            $this->assertSame(['id', 'name', 'role', 'permissions'], array_keys($byRole[$role]));
        }
    }

    public function test_revoked_inactive_and_foreign_memberships_never_leak(): void
    {
        $user = User::factory()->create();
        $foreignUser = User::factory()->create();
        $ownId = $this->organization('Own');
        $revokedId = $this->organization('Revoked');
        $inactiveId = $this->organization('Inactive');
        $foreignId = $this->organization('Foreign');
        $this->membership($user, $ownId, 'viewer');
        $revokedMembership = $this->membership($user, $revokedId, 'admin');
        DB::table('organization_memberships')->where('id', $revokedMembership)->update(['active' => false]);
        $this->membership($user, $inactiveId, 'operator', false);
        $this->membership($foreignUser, $foreignId, 'owner');
        $token = $user->createToken('active')->plainTextToken;

        $this->withToken($token)->getJson('/api/v1/auth/organizations')
            ->assertOk()->assertExactJson(['data' => [[
                'id' => $ownId, 'name' => 'Own', 'role' => 'viewer', 'permissions' => ['buildings.view', 'equipment.view', 'floors.view', 'zones.view'],
            ]]]);
    }

    public function test_permissions_are_read_from_the_role_mapping_on_each_request(): void
    {
        $user = User::factory()->create();
        $organizationId = $this->organization('Dynamic');
        $this->membership($user, $organizationId, 'operator');
        $token = $user->createToken('active')->plainTextToken;
        DB::table('role_permissions')->insert([
            'role_code' => 'operator', 'permission_code' => 'users.view',
        ]);

        $this->withToken($token)->getJson('/api/v1/auth/organizations')
            ->assertOk()->assertJsonPath('data.0.permissions.0', 'buildings.view')
            ->assertJsonPath('data.0.permissions.1', 'equipment.view')
            ->assertJsonPath('data.0.permissions.2', 'floors.view')
            ->assertJsonPath('data.0.permissions.3', 'users.view');
    }
}
