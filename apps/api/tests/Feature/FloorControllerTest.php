<?php

namespace Tests\Feature;

use App\Models\Organization;
use App\Models\User;
use Illuminate\Database\Events\QueryExecuted;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use Tests\TestCase;

class FloorControllerTest extends TestCase
{
    use RefreshDatabase;

    private function organization(): string
    {
        $id = (string) Str::uuid();
        DB::table('organizations')->insert(['id' => $id, 'name' => 'North', 'slug' => $id, 'timezone' => 'UTC']);

        return $id;
    }

    private function building(string $organization): string
    {
        $id = (string) Str::uuid();
        DB::table('buildings')->insert(['id' => $id, 'organization_id' => $organization,
            'name' => 'Office', 'code' => $id, 'timezone' => 'UTC']);

        return $id;
    }

    private function member(string $organization, string $role): User
    {
        $user = User::factory()->create();
        DB::table('organization_memberships')->insert(['id' => (string) Str::uuid(),
            'organization_id' => $organization, 'user_id' => $user->id, 'role' => $role, 'active' => true]);
        $this->withToken($user->createToken('floor-test')->plainTextToken);

        return $user;
    }

    private function base(string $organization, string $building): string
    {
        return "/api/v1/organizations/$organization/buildings/$building/floors";
    }

    public function test_floor_zone_permissions_cover_all_roles_and_rollback_cleanly(): void
    {
        $organizationId = $this->organization();
        $organization = Organization::findOrFail($organizationId);
        foreach (['viewer', 'operator', 'admin', 'owner'] as $role) {
            $user = $this->member($organizationId, $role);
            $this->assertTrue(Gate::forUser($user)->allows('viewFloors', $organization));
            $this->assertTrue(Gate::forUser($user)->allows('viewZones', $organization));
            $canManage = in_array($role, ['admin', 'owner'], true);
            $this->assertSame($canManage, Gate::forUser($user)->allows('manageFloors', $organization));
            $this->assertSame($canManage, Gate::forUser($user)->allows('manageZones', $organization));
        }
        $migration = require database_path('migrations/2026_11_19_144648_add_floor_zone_permissions.php');
        $migration->down();
        $this->assertDatabaseMissing('permissions', ['code' => 'floors.view']);
        $this->assertDatabaseHas('permissions', ['code' => 'buildings.view']);
        $migration->up();
        $this->assertDatabaseHas('role_permissions', ['role_code' => 'owner',
            'permission_code' => 'zones.manage']);
    }

    public function test_hierarchy_migration_rolls_back_only_new_tables(): void
    {
        $migration = require database_path('migrations/2026_11_19_144647_create_floors_and_zones_tables.php');

        $migration->down();
        $this->assertFalse(Schema::hasTable('floors'));
        $this->assertFalse(Schema::hasTable('zones'));
        $this->assertTrue(Schema::hasTable('buildings'));
        $migration->up();
        $this->assertTrue(Schema::hasTable('floors'));
        $this->assertTrue(Schema::hasTable('zones'));
    }

    public function test_floor_rejects_expired_revoked_and_inactive_credentials(): void
    {
        $organization = $this->organization();
        $building = $this->building($organization);
        $base = $this->base($organization, $building);
        $user = $this->member($organization, 'owner');
        $expired = $user->createToken('expired', ['*'], now()->addMinute())->plainTextToken;
        $this->travel(2)->minutes();
        Auth::forgetGuards();
        $this->withToken($expired)->getJson($base)->assertUnauthorized();
        $this->travelBack();
        $revoked = $user->createToken('revoked');
        $revoked->accessToken->delete();
        Auth::forgetGuards();
        $this->withToken($revoked->plainTextToken)->getJson($base)->assertUnauthorized();
        DB::table('users')->where('id', $user->id)->update(['is_active' => false]);
        Auth::forgetGuards();
        $this->withToken($user->createToken('disabled')->plainTextToken)
            ->getJson($base)->assertUnauthorized();
    }

    public function test_owner_creates_basement_floor_with_server_parents_and_audit(): void
    {
        $organization = $this->organization();
        $building = $this->building($organization);
        $owner = $this->member($organization, 'owner');

        $response = $this->postJson($this->base($organization, $building),
            ['name' => 'Basement', 'code' => 'B1', 'level' => -1])
            ->assertCreated()->assertJsonPath('data.level', -1)
            ->assertJsonPath('data.organization_id', $organization)
            ->assertJsonPath('data.building_id', $building);
        $floor = $response->json('data.id');
        $this->assertTrue(Str::isUuid($floor));
        $this->assertDatabaseHas('floors', ['id' => $floor, 'level' => -1]);
        $this->assertDatabaseHas('audit_events', ['organization_id' => $organization,
            'actor_user_id' => $owner->id, 'action' => 'floor.created',
            'subject_type' => 'floor', 'subject_id' => $floor]);
    }

    public function test_floor_list_detail_update_and_pagination_are_building_scoped(): void
    {
        $organization = $this->organization();
        $building = $this->building($organization);
        $otherBuilding = $this->building($organization);
        $owner = $this->member($organization, 'owner');
        $base = $this->base($organization, $building);
        foreach (['C-003', 'A-001', 'B-002'] as $code) {
            $this->postJson($base, ['name' => $code, 'code' => $code, 'level' => 0])->assertCreated();
        }
        $other = $this->postJson($this->base($organization, $otherBuilding),
            ['name' => 'Other', 'code' => 'A-001', 'level' => 0])->assertCreated()->json('data.id');

        $page = $this->getJson("$base?per_page=2")->assertOk()
            ->assertJsonPath('data.0.code', 'A-001')->assertJsonPath('meta.total', 3)
            ->assertJsonPath('meta.last_page', 2);
        $first = $page->json('data.0.id');
        $this->getJson("$base?per_page=2&page=2")->assertOk()
            ->assertJsonPath('data.0.code', 'C-003');
        $this->getJson("$base/$first")->assertOk()->assertJsonPath('data.id', $first);
        $this->patchJson("$base/$first", ['name' => 'Renamed', 'level' => -2])
            ->assertOk()->assertJsonPath('data.level', -2);
        $this->assertDatabaseHas('audit_events', ['action' => 'floor.updated',
            'actor_user_id' => $owner->id, 'subject_id' => $first]);
        $this->getJson("$base/$other")->assertNotFound();
        $this->patchJson("$base/$other", ['name' => 'Denied'])->assertNotFound();
        $this->getJson("$base?per_page=101")->assertUnprocessable();
        $this->getJson("$base?page=0")->assertUnprocessable();
    }

    public function test_floor_permissions_and_missing_membership_are_enforced(): void
    {
        $organization = $this->organization();
        $building = $this->building($organization);
        $base = $this->base($organization, $building);
        $this->getJson($base)->assertUnauthorized();
        foreach (['viewer', 'operator', 'admin', 'owner'] as $role) {
            $this->member($organization, $role);
            $this->getJson($base)->assertOk();
            $response = $this->postJson($base,
                ['name' => $role, 'code' => strtoupper($role), 'level' => 1]);
            in_array($role, ['admin', 'owner'], true)
                ? $response->assertCreated() : $response->assertForbidden();
            Auth::forgetGuards();
        }
        $foreign = $this->organization();
        $this->member($foreign, 'owner');
        $this->getJson($base)->assertNotFound();
        $this->postJson($base, ['name' => 'No', 'code' => 'NO', 'level' => 0])->assertNotFound();
    }

    public function test_floor_validation_rejects_duplicate_code_and_parent_injection(): void
    {
        $organization = $this->organization();
        $building = $this->building($organization);
        $other = $this->building($organization);
        $this->member($organization, 'owner');
        $base = $this->base($organization, $building);
        $floor = $this->postJson($base, ['name' => 'Ground', 'code' => 'G', 'level' => 0])
            ->assertCreated()->json('data.id');

        $this->postJson($base, ['name' => 'Again', 'code' => 'G', 'level' => 1])
            ->assertUnprocessable()->assertJsonValidationErrors('code');
        $this->postJson($base, ['name' => '', 'code' => 'bad code', 'level' => 2147483648])
            ->assertUnprocessable()->assertJsonValidationErrors(['name', 'code', 'level']);
        $this->postJson($base, ['name' => 'Injected', 'code' => 'X', 'level' => 0,
            'organization_id' => $organization, 'building_id' => $other])
            ->assertUnprocessable()->assertJsonValidationErrors(['organization_id', 'building_id']);
        $this->patchJson("$base/$floor", ['building_id' => $other])
            ->assertUnprocessable()->assertJsonValidationErrors('building_id');
        $this->patchJson("$base/$floor", [])->assertUnprocessable();
        $this->deleteJson("$base/$floor")->assertStatus(405);
    }

    public function test_database_rejects_foreign_floor_parent_and_reparenting(): void
    {
        $organization = $this->organization();
        $foreign = $this->organization();
        $building = $this->building($organization);
        $other = $this->building($foreign);
        $floor = (string) Str::uuid();
        try {
            DB::transaction(fn () => DB::table('floors')->insert(['id' => $floor, 'organization_id' => $foreign,
                'building_id' => $building, 'name' => 'Invalid', 'code' => 'I', 'level' => 0]));
            $this->fail('Mismatched floor parent was accepted');
        } catch (QueryException $exception) {
            $this->assertDatabaseMissing('floors', ['id' => $floor]);
        }
        DB::table('floors')->insert(['id' => $floor, 'organization_id' => $organization,
            'building_id' => $building, 'name' => 'Valid', 'code' => 'V', 'level' => 0]);
        try {
            DB::transaction(fn () => DB::table('floors')->where('id', $floor)->update(['building_id' => $other,
                'organization_id' => $foreign]));
            $this->fail('Floor reparenting was accepted');
        } catch (QueryException $exception) {
            $this->assertDatabaseHas('floors', ['id' => $floor, 'building_id' => $building]);
        }
        try {
            DB::transaction(fn () => DB::table('buildings')->where('id', $building)
                ->update(['organization_id' => $foreign]));
            $this->fail('Building tenant change with floors was accepted');
        } catch (QueryException $exception) {
            $this->assertDatabaseHas('buildings', ['id' => $building, 'organization_id' => $organization]);
        }
    }

    public function test_database_unique_code_and_parent_delete_restriction_protect_floor(): void
    {
        $organization = $this->organization();
        $building = $this->building($organization);
        $first = (string) Str::uuid();
        DB::table('floors')->insert(['id' => $first, 'organization_id' => $organization,
            'building_id' => $building, 'name' => 'First', 'code' => 'G', 'level' => 0]);

        try {
            DB::transaction(fn () => DB::table('floors')->insert(['id' => (string) Str::uuid(),
                'organization_id' => $organization, 'building_id' => $building,
                'name' => 'Duplicate', 'code' => 'G', 'level' => 1]));
            $this->fail('Duplicate floor code was accepted');
        } catch (QueryException $exception) {
            $this->assertDatabaseCount('floors', 1);
        }
        try {
            DB::transaction(fn () => DB::table('buildings')->where('id', $building)->delete());
            $this->fail('Building with floors was deleted');
        } catch (QueryException $exception) {
            $this->assertDatabaseHas('buildings', ['id' => $building]);
        }
    }

    public function test_floor_create_rolls_back_when_audit_insert_fails(): void
    {
        $organization = $this->organization();
        $building = $this->building($organization);
        $this->member($organization, 'owner');
        if (DB::getDriverName() === 'sqlite') {
            DB::unprepared("CREATE TRIGGER fail_floor_audit BEFORE INSERT ON audit_events WHEN NEW.action = 'floor.created' BEGIN SELECT RAISE(ABORT, 'audit blocked'); END");
        } else {
            DB::unprepared("CREATE OR REPLACE FUNCTION fail_floor_audit() RETURNS trigger LANGUAGE plpgsql AS \$\$ BEGIN IF NEW.action = 'floor.created' THEN RAISE EXCEPTION 'audit blocked'; END IF; RETURN NEW; END; \$\$");
            DB::unprepared('CREATE TRIGGER fail_floor_audit BEFORE INSERT ON audit_events FOR EACH ROW EXECUTE FUNCTION fail_floor_audit()');
        }

        $this->postJson($this->base($organization, $building),
            ['name' => 'No audit', 'code' => 'NA', 'level' => 0])->assertStatus(500);
        $this->assertDatabaseMissing('floors', ['building_id' => $building, 'code' => 'NA']);
    }

    public function test_floor_update_rolls_back_when_audit_insert_fails(): void
    {
        $organization = $this->organization();
        $building = $this->building($organization);
        $this->member($organization, 'owner');
        $base = $this->base($organization, $building);
        $floor = $this->postJson($base, ['name' => 'Original', 'code' => 'ORIG', 'level' => 0])
            ->assertCreated()->json('data.id');
        if (DB::getDriverName() === 'sqlite') {
            DB::unprepared("CREATE TRIGGER fail_floor_update_audit BEFORE INSERT ON audit_events WHEN NEW.action = 'floor.updated' BEGIN SELECT RAISE(ABORT, 'audit blocked'); END");
        } else {
            DB::unprepared("CREATE OR REPLACE FUNCTION fail_floor_update_audit() RETURNS trigger LANGUAGE plpgsql AS \$\$ BEGIN IF NEW.action = 'floor.updated' THEN RAISE EXCEPTION 'audit blocked'; END IF; RETURN NEW; END; \$\$");
            DB::unprepared('CREATE TRIGGER fail_floor_update_audit BEFORE INSERT ON audit_events FOR EACH ROW EXECUTE FUNCTION fail_floor_update_audit()');
        }

        $this->patchJson("$base/$floor", ['name' => 'Changed'])->assertStatus(500);
        $this->assertDatabaseHas('floors', ['id' => $floor, 'name' => 'Original']);
        $this->assertDatabaseMissing('audit_events', ['action' => 'floor.updated', 'subject_id' => $floor]);
    }

    public function test_floor_unique_race_returns_validation_error_without_audit(): void
    {
        $organization = $this->organization();
        $building = $this->building($organization);
        $this->member($organization, 'owner');
        $inserted = false;
        DB::listen(function (QueryExecuted $query) use (&$inserted, $organization, $building): void {
            if ($inserted || ! str_contains($query->sql, 'from "floors"') ||
                ! str_contains($query->sql, 'count(') || ! in_array('RACE', $query->bindings, true)) {
                return;
            }
            $inserted = true;
            DB::table('floors')->insert(['id' => (string) Str::uuid(),
                'organization_id' => $organization, 'building_id' => $building,
                'name' => 'Other request', 'code' => 'RACE', 'level' => 0]);
        });

        $this->postJson($this->base($organization, $building),
            ['name' => 'Our request', 'code' => 'RACE', 'level' => 1])
            ->assertUnprocessable()->assertJsonValidationErrors('code');
        $this->assertTrue($inserted);
        $this->assertDatabaseCount('floors', 1);
        $this->assertDatabaseMissing('audit_events', ['action' => 'floor.created']);
    }

    public function test_malformed_uuid_path_segments_return_404(): void
    {
        $organization = $this->organization();
        $building = $this->building($organization);
        $this->member($organization, 'owner');
        $base = $this->base($organization, $building);
        $floor = $this->postJson($base, ['name' => 'Ground', 'code' => 'G', 'level' => 0])
            ->assertCreated()->json('data.id');

        $this->getJson("/api/v1/organizations/not-a-uuid/buildings/$building/floors")
            ->assertNotFound();
        $this->postJson("/api/v1/organizations/$organization/buildings/not-a-uuid/floors",
            ['name' => 'No', 'code' => 'NO', 'level' => 0])->assertNotFound();
        $this->getJson("$base/not-a-uuid")->assertNotFound();
        $this->patchJson("$base/not-a-uuid", ['name' => 'No'])->assertNotFound();
        $this->getJson("$base/$floor")->assertOk();
    }

    public function test_null_and_empty_parent_identifiers_are_rejected(): void
    {
        $organization = $this->organization();
        $building = $this->building($organization);
        $this->member($organization, 'owner');
        $base = $this->base($organization, $building);
        $floor = $this->postJson($base, ['name' => 'Ground', 'code' => 'G', 'level' => 0])
            ->assertCreated()->json('data.id');

        foreach ([null, ''] as $value) {
            $this->postJson($base, ['name' => 'No', 'code' => 'NO', 'level' => 0,
                'organization_id' => $value, 'building_id' => $value])
                ->assertUnprocessable()->assertJsonValidationErrors(['organization_id', 'building_id']);
            $this->patchJson("$base/$floor", ['organization_id' => $value,
                'building_id' => $value])
                ->assertUnprocessable()->assertJsonValidationErrors(['organization_id', 'building_id']);
        }
        $this->assertDatabaseCount('floors', 1);
    }

    public function test_non_unique_database_error_named_like_code_constraint_is_not_422(): void
    {
        $organization = $this->organization();
        $building = $this->building($organization);
        $this->member($organization, 'owner');
        if (DB::getDriverName() === 'sqlite') {
            DB::unprepared("CREATE TRIGGER floor_decoy_error BEFORE INSERT ON floors WHEN NEW.code = 'DECOY' BEGIN SELECT RAISE(ABORT, 'floors_building_id_code_unique'); END");
        } else {
            DB::unprepared("CREATE OR REPLACE FUNCTION floor_decoy_error() RETURNS trigger LANGUAGE plpgsql AS \$\$ BEGIN IF NEW.code = 'DECOY' THEN RAISE EXCEPTION 'floors_building_id_code_unique'; END IF; RETURN NEW; END; \$\$");
            DB::unprepared('CREATE TRIGGER floor_decoy_error BEFORE INSERT ON floors FOR EACH ROW EXECUTE FUNCTION floor_decoy_error()');
        }

        $this->postJson($this->base($organization, $building),
            ['name' => 'Decoy', 'code' => 'DECOY', 'level' => 0])->assertStatus(500);
        $this->assertDatabaseMissing('floors', ['code' => 'DECOY']);
    }
}
