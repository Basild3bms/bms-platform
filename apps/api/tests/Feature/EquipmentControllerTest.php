<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Database\Events\QueryExecuted;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use Tests\TestCase;

class EquipmentControllerTest extends TestCase
{
    use RefreshDatabase;

    private function hierarchy(): array
    {
        $organization = (string) Str::uuid();
        $building = (string) Str::uuid();
        $floor = (string) Str::uuid();
        $zone = (string) Str::uuid();
        DB::table('organizations')->insert(['id' => $organization, 'name' => 'North', 'slug' => $organization, 'timezone' => 'UTC']);
        DB::table('buildings')->insert(['id' => $building, 'organization_id' => $organization, 'name' => 'Office', 'code' => 'B', 'timezone' => 'UTC']);
        DB::table('floors')->insert(['id' => $floor, 'organization_id' => $organization, 'building_id' => $building, 'name' => 'Ground', 'code' => 'G', 'level' => 0]);
        DB::table('zones')->insert(['id' => $zone, 'organization_id' => $organization, 'building_id' => $building, 'floor_id' => $floor, 'name' => 'Plant', 'code' => 'P', 'zone_type' => 'plant_room']);

        return [$organization, $building, $floor, $zone];
    }

    private function member(string $organization, string $role = 'owner'): User
    {
        $user = User::factory()->create();
        DB::table('organization_memberships')->insert(['id' => (string) Str::uuid(), 'organization_id' => $organization, 'user_id' => $user->id, 'role' => $role, 'active' => true]);
        $this->withToken($user->createToken('equipment-test')->plainTextToken);

        return $user;
    }

    private function base(string $organization, string $building): string
    {
        return "/api/v1/organizations/$organization/buildings/$building/equipment";
    }

    private function payload(string $code = 'AHU-01'): array
    {
        return ['code' => $code, 'name' => 'Supply AHU', 'type_code' => 'ahu'];
    }

    private function assertRejectedUpdatePreservesState(string $base, string $item, array $payload, string|array $errors): void
    {
        $before = DB::table('equipment')->where('id', $item)->first();
        $auditCount = DB::table('audit_events')->count();
        $this->patchJson("$base/$item", $payload)->assertUnprocessable()->assertJsonValidationErrors($errors);
        $this->assertEquals($before, DB::table('equipment')->where('id', $item)->first());
        $this->assertSame($auditCount, DB::table('audit_events')->count());
    }

    private function assertRejectedCreatePreservesState(string $base, array $payload, string|array $errors): void
    {
        $equipmentCount = DB::table('equipment')->count();
        $auditCount = DB::table('audit_events')->count();
        $this->postJson($base, $payload)->assertUnprocessable()->assertJsonValidationErrors($errors);
        $this->assertSame($equipmentCount, DB::table('equipment')->count());
        $this->assertSame($auditCount, DB::table('audit_events')->count());
    }

    public function test_location_levels_audit_and_retirement(): void
    {
        [$organization, $building, $floor, $zone] = $this->hierarchy();
        $actor = $this->member($organization);
        $base = $this->base($organization, $building);
        $buildingItem = $this->postJson($base, $this->payload(' roof-ahu '))->assertCreated()
            ->assertJsonPath('data.code', 'ROOF-AHU')->assertJsonPath('data.floor_id', null)->json('data.id');
        $this->postJson("/api/v1/organizations/$organization/buildings/$building/floors/$floor/equipment", $this->payload('FCU-01'))
            ->assertCreated()->assertJsonPath('data.floor_id', $floor)->assertJsonPath('data.zone_id', null);
        $this->postJson("/api/v1/organizations/$organization/buildings/$building/floors/$floor/zones/$zone/equipment", $this->payload('VAV-01'))
            ->assertCreated()->assertJsonPath('data.zone_id', $zone);
        $this->assertDatabaseHas('audit_events', ['actor_user_id' => $actor->id, 'action' => 'equipment.created', 'subject_id' => $buildingItem]);
        $this->patchJson("$base/$buildingItem", ['lifecycle_status' => 'retired'])->assertOk()
            ->assertJsonPath('data.lifecycle_status', 'retired');
        $this->assertDatabaseHas('audit_events', ['action' => 'equipment.updated', 'subject_id' => $buildingItem]);
        $this->deleteJson("$base/$buildingItem")->assertStatus(405);
        $this->postJson("$base/$buildingItem/control", [])->assertNotFound();
    }

    public function test_authentication_roles_membership_and_tenant_scope(): void
    {
        [$organization, $building, $floor] = $this->hierarchy();
        [$otherOrganization, $otherBuilding, $otherFloor] = $this->hierarchy();
        $base = $this->base($organization, $building);
        $this->getJson($base)->assertUnauthorized();
        $item = (string) Str::uuid();
        DB::table('equipment')->insert(['id' => $item, 'organization_id' => $organization,
            'building_id' => $building, 'code' => 'EXISTING', 'name' => 'Existing',
            'type_code' => 'ahu', 'lifecycle_status' => 'planned']);
        foreach (['viewer', 'operator', 'admin', 'owner'] as $role) {
            $user = $this->member($organization, $role);
            $this->getJson($base)->assertOk();
            $this->getJson("$base/$item")->assertOk();
            $result = $this->postJson($base, $this->payload(strtoupper($role)));
            in_array($role, ['admin', 'owner'], true) ? $result->assertCreated() : $result->assertForbidden();
            $updated = $this->patchJson("$base/$item", ['name' => 'Updated by '.$role]);
            in_array($role, ['admin', 'owner'], true) ? $updated->assertOk() : $updated->assertForbidden();
            if ($role === 'viewer') {
                DB::table('organization_memberships')->where('user_id', $user->id)->update(['active' => false]);
                $this->getJson($base)->assertNotFound();
            }
            Auth::forgetGuards();
        }
        $this->member($organization);
        $this->getJson($this->base($otherOrganization, $otherBuilding))->assertNotFound();
        $this->postJson("/api/v1/organizations/$organization/buildings/$building/floors/$otherFloor/equipment", $this->payload('X'))
            ->assertNotFound();
        $this->getJson("$base/not-a-uuid")->assertNotFound();
        $this->getJson("/api/v1/organizations/not-a-uuid/buildings/$building/equipment")->assertNotFound();
    }

    public function test_validation_code_uniqueness_and_list_filters(): void
    {
        [$organization, $building, $floor, $zone] = $this->hierarchy();
        $this->member($organization);
        $base = $this->base($organization, $building);
        foreach (['C', 'A', 'B'] as $code) {
            $this->postJson($base, $this->payload($code))->assertCreated();
        }
        $this->postJson($base, $this->payload(' a '))->assertUnprocessable()->assertJsonValidationErrors('code');
        $this->postJson($base, [...$this->payload('X'), 'floor_id' => null, 'organization_id' => $organization])
            ->assertUnprocessable()->assertJsonValidationErrors(['floor_id', 'organization_id']);
        $this->postJson($base, [...$this->payload('X'), 'type_code' => 'bad'])->assertUnprocessable()->assertJsonValidationErrors('type_code');
        $this->postJson($base, [...$this->payload('X'), 'lifecycle_status' => 'bad'])->assertUnprocessable()->assertJsonValidationErrors('lifecycle_status');
        $this->postJson($base, [...$this->payload('X'), 'specifications' => ['password' => 'secret'], 'spec_schema_version' => 1])
            ->assertUnprocessable()->assertJsonValidationErrors('specifications');
        $this->postJson($base, [...$this->payload('X'), 'specifications' => ['design_airflow_m3_h' => 1000], 'spec_schema_version' => 1])
            ->assertCreated();
        $this->postJson($base, [...$this->payload('EMPTY'), 'specifications' => (object) [], 'spec_schema_version' => 1])
            ->assertCreated()->assertJsonPath('data.spec_schema_version', 1);
        $this->getJson("$base?per_page=2")->assertOk()->assertJsonPath('data.0.code', 'A')->assertJsonPath('meta.total', 5);
        $this->getJson("$base?type_code=ahu&lifecycle_status=planned&q=B")->assertOk()->assertJsonPath('meta.total', 1);
        $this->getJson("$base?floor_id=$floor")->assertOk()->assertJsonPath('meta.total', 0);
        $this->getJson("$base?zone_id=$zone")->assertOk()->assertJsonPath('meta.total', 0);
        $this->getJson("$base?per_page=101")->assertUnprocessable();
    }

    public function test_database_parent_integrity_code_uniqueness_and_restrictive_delete(): void
    {
        [$organization, $building, $floor, $zone] = $this->hierarchy();
        [$otherOrganization, $otherBuilding, $otherFloor, $otherZone] = $this->hierarchy();
        $valid = ['id' => (string) Str::uuid(), 'organization_id' => $organization, 'building_id' => $building,
            'floor_id' => $floor, 'zone_id' => $zone, 'code' => 'AHU-01', 'name' => 'AHU',
            'type_code' => 'ahu', 'lifecycle_status' => 'planned'];
        foreach ([['organization_id' => $otherOrganization], ['floor_id' => $otherFloor],
            ['zone_id' => $otherZone], ['floor_id' => null]] as $changes) {
            $bad = [...$valid, ...$changes, 'id' => (string) Str::uuid()];
            try {
                DB::transaction(fn () => DB::table('equipment')->insert($bad));
                $this->fail('Invalid equipment parent was accepted');
            } catch (QueryException $exception) {
                $this->assertDatabaseMissing('equipment', ['id' => $bad['id']]);
            }
        }
        DB::table('equipment')->insert($valid);
        foreach ([['lifecycle_status' => 'running'], ['specifications' => '[]', 'spec_schema_version' => 1],
            ['specifications' => '{}', 'spec_schema_version' => null], ['code' => 'ahu-02'],
            ['installed_on' => '2026-11-21', 'commissioned_on' => '2026-11-20']] as $index => $changes) {
            $bad = [...$valid, ...$changes, 'id' => (string) Str::uuid(), 'code' => $changes['code'] ?? 'BAD-'.$index];
            try {
                DB::transaction(fn () => DB::table('equipment')->insert($bad));
                $this->fail('Invalid equipment values were accepted');
            } catch (QueryException $exception) {
                $this->assertDatabaseMissing('equipment', ['id' => $bad['id']]);
            }
        }
        foreach ([
            fn () => DB::table('equipment')->insert([...$valid, 'id' => (string) Str::uuid(), 'code' => 'ahu-01']),
            fn () => DB::table('equipment')->where('id', $valid['id'])->update(['building_id' => $otherBuilding]),
            fn () => DB::table('zones')->where('id', $zone)->delete(),
            fn () => DB::table('floors')->where('id', $floor)->delete(),
            fn () => DB::table('buildings')->where('id', $building)->delete(),
        ] as $operation) {
            try {
                DB::transaction($operation);
                $this->fail('Invalid database operation was accepted');
            } catch (QueryException $exception) {
                $this->assertDatabaseHas('equipment', ['id' => $valid['id'], 'building_id' => $building]);
            }
        }
    }

    public function test_audit_failure_rolls_back_equipment_change(): void
    {
        [$organization, $building] = $this->hierarchy();
        $this->member($organization);
        $base = $this->base($organization, $building);
        $item = $this->postJson($base, $this->payload())->assertCreated()->json('data.id');
        if (DB::getDriverName() === 'sqlite') {
            DB::unprepared("CREATE TRIGGER fail_equipment_audit BEFORE INSERT ON audit_events WHEN NEW.action IN ('equipment.created', 'equipment.updated') BEGIN SELECT RAISE(ABORT, 'audit blocked'); END");
        } else {
            DB::unprepared("CREATE OR REPLACE FUNCTION fail_equipment_audit() RETURNS trigger LANGUAGE plpgsql AS \$\$ BEGIN IF NEW.action IN ('equipment.created', 'equipment.updated') THEN RAISE EXCEPTION 'audit blocked'; END IF; RETURN NEW; END; \$\$");
            DB::unprepared('CREATE TRIGGER fail_equipment_audit BEFORE INSERT ON audit_events FOR EACH ROW EXECUTE FUNCTION fail_equipment_audit()');
        }
        $this->postJson($base, $this->payload('NEW'))->assertStatus(500);
        $this->patchJson("$base/$item", ['name' => 'Changed'])->assertStatus(500);
        $this->assertDatabaseMissing('equipment', ['code' => 'NEW']);
        $this->assertDatabaseHas('equipment', ['id' => $item, 'name' => 'Supply AHU']);
    }

    public function test_equipment_migration_rollback_preserves_legacy_tables(): void
    {
        $migration = require database_path('migrations/2026_11_20_063357_create_equipment_inventory_tables.php');
        $migration->down();
        $this->assertFalse(Schema::hasTable('equipment'));
        $this->assertFalse(Schema::hasTable('equipment_types'));
        foreach (['organizations', 'buildings', 'floors', 'zones', 'devices', 'device_points'] as $table) {
            $this->assertTrue(Schema::hasTable($table));
        }
        $migration->up();
        $this->assertTrue(Schema::hasTable('equipment'));
        $this->assertDatabaseCount('equipment_types', 17);
    }

    public function test_permission_migration_rolls_back_only_equipment_permissions(): void
    {
        $migration = require database_path('migrations/2026_11_20_063358_add_equipment_permissions.php');
        $migration->down();
        $this->assertDatabaseMissing('permissions', ['code' => 'equipment.view']);
        $this->assertDatabaseHas('permissions', ['code' => 'buildings.view']);
        $migration->up();
        foreach (['viewer', 'operator', 'admin', 'owner'] as $role) {
            $this->assertDatabaseHas('role_permissions', ['role_code' => $role, 'permission_code' => 'equipment.view']);
            if (in_array($role, ['admin', 'owner'], true)) {
                $this->assertDatabaseHas('role_permissions', ['role_code' => $role, 'permission_code' => 'equipment.manage']);
            } else {
                $this->assertDatabaseMissing('role_permissions', ['role_code' => $role, 'permission_code' => 'equipment.manage']);
            }
        }
    }

    public function test_unique_code_race_returns_422_without_audit(): void
    {
        [$organization, $building] = $this->hierarchy();
        $this->member($organization);
        $inserted = false;
        DB::listen(function (QueryExecuted $query) use (&$inserted, $organization, $building): void {
            if ($inserted || ! str_contains($query->sql, 'from "equipment"') ||
                ! str_contains($query->sql, 'count(') || ! in_array('RACE', $query->bindings, true)) {
                return;
            }
            $inserted = true;
            DB::table('equipment')->insert(['id' => (string) Str::uuid(), 'organization_id' => $organization,
                'building_id' => $building, 'code' => 'RACE', 'name' => 'Other request',
                'type_code' => 'ahu', 'lifecycle_status' => 'planned']);
        });
        $this->postJson($this->base($organization, $building), $this->payload('RACE'))
            ->assertUnprocessable()->assertJsonValidationErrors('code');
        $this->assertTrue($inserted);
        $this->assertDatabaseCount('equipment', 1);
        $this->assertDatabaseMissing('audit_events', ['action' => 'equipment.created']);
    }

    public function test_specification_and_location_validation_on_update(): void
    {
        [$organization, $building, $floor, $zone] = $this->hierarchy();
        $this->member($organization);
        $base = $this->base($organization, $building);
        $item = $this->postJson($base, $this->payload())->assertCreated()->json('data.id');
        foreach ([null, '', $floor] as $value) {
            $this->patchJson("$base/$item", ['floor_id' => $value])
                ->assertUnprocessable()->assertJsonValidationErrors('floor_id');
            $this->postJson($base, [...$this->payload('NEW'), 'zone_id' => $value])
                ->assertUnprocessable()->assertJsonValidationErrors('zone_id');
        }
        $this->patchJson("$base/$item", [])->assertUnprocessable();
        $this->patchJson("$base/$item", ['specifications' => ['design_airflow_m3_h' => -1],
            'spec_schema_version' => 1])->assertUnprocessable()->assertJsonValidationErrors('specifications');
        $this->patchJson("$base/$item", ['installed_on' => '2026-11-21', 'commissioned_on' => '2026-11-20'])
            ->assertUnprocessable()->assertJsonValidationErrors('commissioned_on');
        $this->patchJson("$base/$item", ['type_code' => 'other'])
            ->assertUnprocessable()->assertJsonValidationErrors('description');
        $this->patchJson("$base/$item", ['type_code' => 'other', 'description' => 'Unclassified asset'])
            ->assertOk();
        $this->patchJson("$base/$item", ['description' => null])
            ->assertUnprocessable()->assertJsonValidationErrors('description');
        $this->patchJson("$base/$item", ['code' => 'ahu-02'])->assertOk()->assertJsonPath('data.code', 'AHU-02');
        $this->getJson("$base/$item")->assertOk()->assertJsonPath('data.id', $item);
    }

    public function test_explicit_null_clears_specifications_and_schema_version(): void
    {
        [$organization, $building] = $this->hierarchy();
        $this->member($organization);
        $base = $this->base($organization, $building);
        $item = $this->postJson($base, [...$this->payload(),
            'specifications' => ['design_airflow_m3_h' => 1000], 'spec_schema_version' => 1])
            ->assertCreated()->json('data.id');

        $this->patchJson("$base/$item", ['specifications' => null])->assertOk()
            ->assertJsonPath('data.specifications', null)
            ->assertJsonPath('data.spec_schema_version', null);
        $this->assertDatabaseHas('equipment', ['id' => $item,
            'specifications' => null, 'spec_schema_version' => null]);

        $this->patchJson("$base/$item", ['specifications' => ['design_airflow_m3_h' => 1200],
            'spec_schema_version' => 1])->assertOk();
        $this->patchJson("$base/$item", ['specifications' => null, 'spec_schema_version' => null])
            ->assertOk()->assertJsonPath('data.specifications', null)
            ->assertJsonPath('data.spec_schema_version', null);
        $this->assertDatabaseHas('equipment', ['id' => $item,
            'specifications' => null, 'spec_schema_version' => null]);
    }

    public function test_type_change_requires_compatible_specs_or_explicit_clear(): void
    {
        [$organization, $building] = $this->hierarchy();
        $this->member($organization);
        $base = $this->base($organization, $building);
        $item = $this->postJson($base, [...$this->payload(),
            'specifications' => ['design_airflow_m3_h' => 1000], 'spec_schema_version' => 1])
            ->assertCreated()->json('data.id');

        $this->assertRejectedUpdatePreservesState($base, $item, ['type_code' => 'chiller'], 'specifications');
        $this->patchJson("$base/$item", ['type_code' => 'fcu'])->assertOk()
            ->assertJsonPath('data.type_code', 'fcu')
            ->assertJsonPath('data.specifications.design_airflow_m3_h', 1000);
        $this->assertRejectedUpdatePreservesState($base, $item, ['type_code' => 'chiller'], 'specifications');
        $this->patchJson("$base/$item", ['type_code' => 'chiller', 'specifications' => null])
            ->assertOk()->assertJsonPath('data.type_code', 'chiller')
            ->assertJsonPath('data.specifications', null)
            ->assertJsonPath('data.spec_schema_version', null);
    }

    public function test_specification_version_reuse_and_missing_version_validation(): void
    {
        [$organization, $building] = $this->hierarchy();
        $this->member($organization);
        $base = $this->base($organization, $building);
        $item = $this->postJson($base, [...$this->payload(),
            'specifications' => ['design_airflow_m3_h' => 1000], 'spec_schema_version' => 1])
            ->assertCreated()->json('data.id');
        $this->patchJson("$base/$item", ['specifications' => ['design_airflow_m3_h' => 1500]])
            ->assertOk()->assertJsonPath('data.specifications.design_airflow_m3_h', 1500)
            ->assertJsonPath('data.spec_schema_version', 1);

        $this->assertRejectedCreatePreservesState($base, [...$this->payload('NEW'),
            'specifications' => ['design_airflow_m3_h' => 1000]], 'spec_schema_version');
        $this->assertRejectedCreatePreservesState($base, [...$this->payload('NEW'),
            'specifications' => ['design_airflow_m3_h' => 1000], 'spec_schema_version' => null],
            'spec_schema_version');
        $empty = $this->postJson($base, $this->payload('EMPTY'))->assertCreated()->json('data.id');
        $this->assertRejectedUpdatePreservesState($base, $empty,
            ['specifications' => ['design_airflow_m3_h' => 1000]], 'spec_schema_version');
    }

    public function test_inactive_catalog_types_are_rejected_on_create_and_update(): void
    {
        [$organization, $building] = $this->hierarchy();
        $this->member($organization);
        $base = $this->base($organization, $building);
        $item = $this->postJson($base, $this->payload())->assertCreated()->json('data.id');
        DB::table('equipment_types')->where('code', 'fcu')->update(['active' => false]);

        $this->assertRejectedCreatePreservesState($base, [...$this->payload('NEW'), 'type_code' => 'fcu'],
            'type_code');
        $this->assertRejectedUpdatePreservesState($base, $item, ['type_code' => 'fcu'], 'type_code');
        $this->patchJson("$base/$item", ['name' => 'Still usable'])->assertOk();
    }

    public function test_update_rejects_unexpected_and_forbidden_fields_without_side_effects(): void
    {
        [$organization, $building] = $this->hierarchy();
        $this->member($organization);
        $base = $this->base($organization, $building);
        $item = $this->postJson($base, $this->payload())->assertCreated()->json('data.id');

        foreach ([
            ['payload' => ['unexpected' => 'value'], 'error' => 'unexpected'],
            ['payload' => ['protocol' => 'bacnet'], 'error' => 'protocol'],
            ['payload' => ['floor_id' => null], 'error' => 'floor_id'],
            ['payload' => ['zone_id' => ''], 'error' => 'zone_id'],
            ['payload' => ['building_id' => null], 'error' => 'building_id'],
            ['payload' => ['organization_id' => null], 'error' => 'organization_id'],
        ] as $case) {
            $this->assertRejectedUpdatePreservesState($base, $item, $case['payload'], $case['error']);
        }
    }

    public function test_second_page_and_incompatible_floor_zone_filters(): void
    {
        [$organization, $building, $floor, $zone] = $this->hierarchy();
        $this->member($organization);
        $base = $this->base($organization, $building);
        foreach (['C', 'A', 'B'] as $code) {
            $this->postJson($base, $this->payload($code))->assertCreated();
        }
        $this->getJson("$base?per_page=2&page=2")->assertOk()
            ->assertJsonCount(1, 'data')->assertJsonPath('data.0.code', 'C')
            ->assertJsonPath('meta.current_page', 2)->assertJsonPath('meta.total', 3);

        $otherFloor = (string) Str::uuid();
        $otherZone = (string) Str::uuid();
        DB::table('floors')->insert(['id' => $otherFloor, 'organization_id' => $organization,
            'building_id' => $building, 'name' => 'First', 'code' => 'F', 'level' => 1]);
        DB::table('zones')->insert(['id' => $otherZone, 'organization_id' => $organization,
            'building_id' => $building, 'floor_id' => $otherFloor, 'name' => 'Office',
            'code' => 'O', 'zone_type' => 'office']);
        $this->getJson("$base?floor_id=$floor&zone_id=$otherZone")
            ->assertUnprocessable()->assertJsonValidationErrors('zone_id');
        $this->getJson("$base?floor_id=$otherFloor&zone_id=$zone")
            ->assertUnprocessable()->assertJsonValidationErrors('zone_id');
        $this->getJson("$base?floor_id=not-a-uuid")->assertUnprocessable()
            ->assertJsonValidationErrors('floor_id');
        $this->getJson("$base?zone_id=not-a-uuid")->assertUnprocessable()
            ->assertJsonValidationErrors('zone_id');
    }

    public function test_database_rejects_each_equipment_parent_update_without_audit(): void
    {
        [$organization, $building, $floor, $zone] = $this->hierarchy();
        [$otherOrganization, $otherBuilding, $otherFloor, $otherZone] = $this->hierarchy();
        $id = (string) Str::uuid();
        DB::table('equipment')->insert(['id' => $id, 'organization_id' => $organization,
            'building_id' => $building, 'floor_id' => $floor, 'zone_id' => $zone,
            'code' => 'AHU-01', 'name' => 'Supply AHU', 'type_code' => 'ahu',
            'lifecycle_status' => 'planned']);

        foreach ([
            ['organization_id' => $otherOrganization],
            ['building_id' => $otherBuilding],
            ['floor_id' => $otherFloor],
            ['zone_id' => $otherZone],
            ['floor_id' => null],
            ['zone_id' => null],
        ] as $change) {
            $before = DB::table('equipment')->where('id', $id)->first();
            $auditCount = DB::table('audit_events')->count();
            try {
                DB::transaction(fn () => DB::table('equipment')->where('id', $id)->update($change));
                $this->fail('Equipment parent update was accepted');
            } catch (QueryException $exception) {
                $this->assertEquals($before, DB::table('equipment')->where('id', $id)->first());
                $this->assertSame($auditCount, DB::table('audit_events')->count());
            }
        }
    }
}
