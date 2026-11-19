<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Database\Events\QueryExecuted;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

class ZoneControllerTest extends TestCase
{
    use RefreshDatabase;

    private function context(): array
    {
        $organization = (string) Str::uuid();
        $building = (string) Str::uuid();
        $floor = (string) Str::uuid();
        DB::table('organizations')->insert(['id' => $organization, 'name' => 'North',
            'slug' => $organization, 'timezone' => 'UTC']);
        DB::table('buildings')->insert(['id' => $building, 'organization_id' => $organization,
            'name' => 'Office', 'code' => 'B', 'timezone' => 'UTC']);
        DB::table('floors')->insert(['id' => $floor, 'organization_id' => $organization,
            'building_id' => $building, 'name' => 'Ground', 'code' => 'G', 'level' => 0]);

        return [$organization, $building, $floor];
    }

    private function member(string $organization, string $role): User
    {
        $user = User::factory()->create();
        DB::table('organization_memberships')->insert(['id' => (string) Str::uuid(),
            'organization_id' => $organization, 'user_id' => $user->id, 'role' => $role, 'active' => true]);
        $this->withToken($user->createToken('zone-test')->plainTextToken);

        return $user;
    }

    private function base(string $organization, string $building, string $floor): string
    {
        return "/api/v1/organizations/$organization/buildings/$building/floors/$floor/zones";
    }

    private function payload(string $code = 'Z-001'): array
    {
        return ['name' => 'Office zone', 'code' => $code, 'zone_type' => 'office'];
    }

    public function test_owner_creates_zone_and_update_is_audited_atomically(): void
    {
        [$organization, $building, $floor] = $this->context();
        $owner = $this->member($organization, 'owner');
        $base = $this->base($organization, $building, $floor);

        $response = $this->postJson($base, $this->payload())->assertCreated()
            ->assertJsonPath('data.organization_id', $organization)
            ->assertJsonPath('data.building_id', $building)
            ->assertJsonPath('data.floor_id', $floor);
        $zone = $response->json('data.id');
        $this->assertTrue(Str::isUuid($zone));
        $this->assertDatabaseHas('audit_events', ['action' => 'zone.created',
            'actor_user_id' => $owner->id, 'subject_type' => 'zone', 'subject_id' => $zone]);
        $this->patchJson("$base/$zone", ['name' => 'Updated', 'zone_type' => 'plant_room'])
            ->assertOk()->assertJsonPath('data.zone_type', 'plant_room');
        $this->assertDatabaseHas('audit_events', ['action' => 'zone.updated',
            'actor_user_id' => $owner->id, 'subject_id' => $zone]);
        $this->assertDatabaseHas('zones', ['id' => $zone, 'name' => 'Updated']);
    }

    public function test_zone_list_is_paginated_stable_and_scoped_to_floor(): void
    {
        [$organization, $building, $floor] = $this->context();
        $otherFloor = (string) Str::uuid();
        DB::table('floors')->insert(['id' => $otherFloor, 'organization_id' => $organization,
            'building_id' => $building, 'name' => 'First', 'code' => 'F', 'level' => 1]);
        $this->member($organization, 'owner');
        $base = $this->base($organization, $building, $floor);
        foreach (['C', 'A', 'B'] as $code) {
            $this->postJson($base, $this->payload($code))->assertCreated();
        }
        $foreignZone = $this->postJson($this->base($organization, $building, $otherFloor),
            $this->payload('A'))->assertCreated()->json('data.id');

        $first = $this->getJson("$base?per_page=2")->assertOk()->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.code', 'A')->assertJsonPath('meta.total', 3)
            ->assertJsonPath('meta.last_page', 2)->json('data.0.id');
        $this->getJson("$base?per_page=2&page=2")->assertOk()->assertJsonPath('data.0.code', 'C');
        $this->getJson("$base/$first")->assertOk()->assertJsonPath('data.id', $first);
        $this->getJson("$base/$foreignZone")->assertNotFound();
        $this->patchJson("$base/$foreignZone", ['name' => 'No'])->assertNotFound();
        $this->getJson("$base?per_page=101")->assertUnprocessable();
    }

    public function test_zone_permissions_and_parent_visibility_are_enforced(): void
    {
        [$organization, $building, $floor] = $this->context();
        $base = $this->base($organization, $building, $floor);
        $this->getJson($base)->assertUnauthorized();
        foreach (['viewer', 'operator', 'admin', 'owner'] as $role) {
            $this->member($organization, $role);
            $this->getJson($base)->assertOk();
            $response = $this->postJson($base, $this->payload(strtoupper($role)));
            in_array($role, ['admin', 'owner'], true)
                ? $response->assertCreated() : $response->assertForbidden();
            Auth::forgetGuards();
        }
        [$foreignOrganization, $foreignBuilding, $foreignFloor] = $this->context();
        $this->member($foreignOrganization, 'owner');
        $this->getJson($base)->assertNotFound();
        $this->getJson($this->base($organization, $foreignBuilding, $foreignFloor))->assertNotFound();
    }

    public function test_zone_inactive_membership_and_missing_view_permission_are_denied(): void
    {
        [$organization, $building, $floor] = $this->context();
        $user = $this->member($organization, 'viewer');
        $base = $this->base($organization, $building, $floor);
        DB::table('role_permissions')->where('role_code', 'viewer')
            ->where('permission_code', 'zones.view')->delete();

        $this->getJson($base)->assertForbidden();
        DB::table('organization_memberships')->where('user_id', $user->id)->update(['active' => false]);
        $this->getJson($base)->assertNotFound();
    }

    public function test_zone_validation_rejects_duplicate_type_and_parent_injection(): void
    {
        [$organization, $building, $floor] = $this->context();
        $this->member($organization, 'owner');
        $base = $this->base($organization, $building, $floor);
        $zone = $this->postJson($base, $this->payload())->assertCreated()->json('data.id');

        $this->postJson($base, $this->payload())->assertUnprocessable()
            ->assertJsonValidationErrors('code');
        $this->postJson($base, [...$this->payload('Z-002'), 'zone_type' => 'nonsense'])
            ->assertUnprocessable()->assertJsonValidationErrors('zone_type');
        $this->postJson($base, [...$this->payload('Z-002'), 'floor_id' => $floor,
            'building_id' => $building, 'organization_id' => $organization])
            ->assertUnprocessable()->assertJsonValidationErrors(['floor_id', 'building_id', 'organization_id']);
        $this->patchJson("$base/$zone", ['floor_id' => $floor])
            ->assertUnprocessable()->assertJsonValidationErrors('floor_id');
        $this->patchJson("$base/$zone", [])->assertUnprocessable();
        $this->deleteJson("$base/$zone")->assertStatus(405);
    }

    public function test_database_rejects_cross_floor_zone_and_reparenting(): void
    {
        [$organization, $building, $floor] = $this->context();
        [$foreignOrganization, $foreignBuilding, $foreignFloor] = $this->context();
        $zone = (string) Str::uuid();
        try {
            DB::transaction(fn () => DB::table('zones')->insert(['id' => $zone, 'organization_id' => $organization,
                'building_id' => $building, 'floor_id' => $foreignFloor,
                'name' => 'Invalid', 'code' => 'I', 'zone_type' => 'office']));
            $this->fail('Cross-floor zone was accepted');
        } catch (QueryException $exception) {
            $this->assertDatabaseMissing('zones', ['id' => $zone]);
        }
        DB::table('zones')->insert(['id' => $zone, 'organization_id' => $organization,
            'building_id' => $building, 'floor_id' => $floor,
            'name' => 'Valid', 'code' => 'V', 'zone_type' => 'office']);
        try {
            DB::transaction(fn () => DB::table('zones')->where('id', $zone)->update(['floor_id' => $foreignFloor,
                'building_id' => $foreignBuilding, 'organization_id' => $foreignOrganization]));
            $this->fail('Zone reparenting was accepted');
        } catch (QueryException $exception) {
            $this->assertDatabaseHas('zones', ['id' => $zone, 'floor_id' => $floor]);
        }
    }

    public function test_database_unique_code_and_parent_delete_restriction_protect_zone(): void
    {
        [$organization, $building, $floor] = $this->context();
        DB::table('zones')->insert(['id' => (string) Str::uuid(),
            'organization_id' => $organization, 'building_id' => $building,
            'floor_id' => $floor, 'name' => 'First', 'code' => 'Z', 'zone_type' => 'office']);
        try {
            DB::transaction(fn () => DB::table('zones')->insert(['id' => (string) Str::uuid(),
                'organization_id' => $organization, 'building_id' => $building,
                'floor_id' => $floor, 'name' => 'Duplicate', 'code' => 'Z', 'zone_type' => 'office']));
            $this->fail('Duplicate zone code was accepted');
        } catch (QueryException $exception) {
            $this->assertDatabaseCount('zones', 1);
        }
        try {
            DB::transaction(fn () => DB::table('floors')->where('id', $floor)->delete());
            $this->fail('Floor with zones was deleted');
        } catch (QueryException $exception) {
            $this->assertDatabaseHas('floors', ['id' => $floor]);
        }
    }

    public function test_zone_create_rolls_back_when_audit_insert_fails(): void
    {
        [$organization, $building, $floor] = $this->context();
        $this->member($organization, 'owner');
        if (DB::getDriverName() === 'sqlite') {
            DB::unprepared("CREATE TRIGGER fail_zone_audit BEFORE INSERT ON audit_events WHEN NEW.action = 'zone.created' BEGIN SELECT RAISE(ABORT, 'audit blocked'); END");
        } else {
            DB::unprepared("CREATE OR REPLACE FUNCTION fail_zone_audit() RETURNS trigger LANGUAGE plpgsql AS \$\$ BEGIN IF NEW.action = 'zone.created' THEN RAISE EXCEPTION 'audit blocked'; END IF; RETURN NEW; END; \$\$");
            DB::unprepared('CREATE TRIGGER fail_zone_audit BEFORE INSERT ON audit_events FOR EACH ROW EXECUTE FUNCTION fail_zone_audit()');
        }

        $this->postJson($this->base($organization, $building, $floor), $this->payload('NA'))
            ->assertStatus(500);
        $this->assertDatabaseMissing('zones', ['floor_id' => $floor, 'code' => 'NA']);
    }

    public function test_zone_update_rolls_back_when_audit_insert_fails(): void
    {
        [$organization, $building, $floor] = $this->context();
        $this->member($organization, 'owner');
        $base = $this->base($organization, $building, $floor);
        $zone = $this->postJson($base, $this->payload())->assertCreated()->json('data.id');
        if (DB::getDriverName() === 'sqlite') {
            DB::unprepared("CREATE TRIGGER fail_zone_update_audit BEFORE INSERT ON audit_events WHEN NEW.action = 'zone.updated' BEGIN SELECT RAISE(ABORT, 'audit blocked'); END");
        } else {
            DB::unprepared("CREATE OR REPLACE FUNCTION fail_zone_update_audit() RETURNS trigger LANGUAGE plpgsql AS \$\$ BEGIN IF NEW.action = 'zone.updated' THEN RAISE EXCEPTION 'audit blocked'; END IF; RETURN NEW; END; \$\$");
            DB::unprepared('CREATE TRIGGER fail_zone_update_audit BEFORE INSERT ON audit_events FOR EACH ROW EXECUTE FUNCTION fail_zone_update_audit()');
        }

        $this->patchJson("$base/$zone", ['name' => 'Changed'])->assertStatus(500);
        $this->assertDatabaseHas('zones', ['id' => $zone, 'name' => 'Office zone']);
        $this->assertDatabaseMissing('audit_events', ['action' => 'zone.updated', 'subject_id' => $zone]);
    }

    public function test_zone_unique_race_returns_validation_error_without_audit(): void
    {
        [$organization, $building, $floor] = $this->context();
        $this->member($organization, 'owner');
        $inserted = false;
        DB::listen(function (QueryExecuted $query) use (&$inserted, $organization, $building, $floor): void {
            if ($inserted || ! str_contains($query->sql, 'from "zones"') ||
                ! str_contains($query->sql, 'count(') || ! in_array('RACE', $query->bindings, true)) {
                return;
            }
            $inserted = true;
            DB::table('zones')->insert(['id' => (string) Str::uuid(),
                'organization_id' => $organization, 'building_id' => $building,
                'floor_id' => $floor, 'name' => 'Other request', 'code' => 'RACE',
                'zone_type' => 'office']);
        });

        $this->postJson($this->base($organization, $building, $floor), $this->payload('RACE'))
            ->assertUnprocessable()->assertJsonValidationErrors('code');
        $this->assertTrue($inserted);
        $this->assertDatabaseCount('zones', 1);
        $this->assertDatabaseMissing('audit_events', ['action' => 'zone.created']);
    }

    public function test_malformed_uuid_path_segments_return_404(): void
    {
        [$organization, $building, $floor] = $this->context();
        $this->member($organization, 'owner');
        $base = $this->base($organization, $building, $floor);
        $zone = $this->postJson($base, $this->payload())->assertCreated()->json('data.id');

        $this->getJson("/api/v1/organizations/not-a-uuid/buildings/$building/floors/$floor/zones")
            ->assertNotFound();
        $this->getJson("/api/v1/organizations/$organization/buildings/not-a-uuid/floors/$floor/zones")
            ->assertNotFound();
        $this->postJson("/api/v1/organizations/$organization/buildings/$building/floors/not-a-uuid/zones",
            $this->payload('NO'))->assertNotFound();
        $this->getJson("$base/not-a-uuid")->assertNotFound();
        $this->patchJson("$base/not-a-uuid", ['name' => 'No'])->assertNotFound();
        $this->getJson("$base/$zone")->assertOk();
    }

    public function test_null_and_empty_parent_identifiers_are_rejected(): void
    {
        [$organization, $building, $floor] = $this->context();
        $this->member($organization, 'owner');
        $base = $this->base($organization, $building, $floor);
        $zone = $this->postJson($base, $this->payload())->assertCreated()->json('data.id');

        foreach ([null, ''] as $value) {
            $this->postJson($base, [...$this->payload('NO'), 'organization_id' => $value,
                'building_id' => $value, 'floor_id' => $value])
                ->assertUnprocessable()->assertJsonValidationErrors(['organization_id', 'building_id', 'floor_id']);
            $this->patchJson("$base/$zone", ['organization_id' => $value,
                'building_id' => $value, 'floor_id' => $value])
                ->assertUnprocessable()->assertJsonValidationErrors(['organization_id', 'building_id', 'floor_id']);
        }
        $this->assertDatabaseCount('zones', 1);
    }

    public function test_non_unique_database_error_named_like_code_constraint_is_not_422(): void
    {
        [$organization, $building, $floor] = $this->context();
        $this->member($organization, 'owner');
        if (DB::getDriverName() === 'sqlite') {
            DB::unprepared("CREATE TRIGGER zone_decoy_error BEFORE INSERT ON zones WHEN NEW.code = 'DECOY' BEGIN SELECT RAISE(ABORT, 'zones_floor_id_code_unique'); END");
        } else {
            DB::unprepared("CREATE OR REPLACE FUNCTION zone_decoy_error() RETURNS trigger LANGUAGE plpgsql AS \$\$ BEGIN IF NEW.code = 'DECOY' THEN RAISE EXCEPTION 'zones_floor_id_code_unique'; END IF; RETURN NEW; END; \$\$");
            DB::unprepared('CREATE TRIGGER zone_decoy_error BEFORE INSERT ON zones FOR EACH ROW EXECUTE FUNCTION zone_decoy_error()');
        }

        $this->postJson($this->base($organization, $building, $floor),
            $this->payload('DECOY'))->assertStatus(500);
        $this->assertDatabaseMissing('zones', ['code' => 'DECOY']);
    }
}
