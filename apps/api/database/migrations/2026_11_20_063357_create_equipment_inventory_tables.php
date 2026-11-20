<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('zones', function (Blueprint $table): void {
            $table->unique(['id', 'floor_id', 'building_id', 'organization_id'], 'zones_equipment_parent_unique');
        });
        Schema::create('equipment_types', function (Blueprint $table): void {
            $table->string('code', 64)->primary();
            $table->string('family', 64);
            $table->string('name', 100);
            $table->boolean('active')->default(true);
        });
        DB::table('equipment_types')->insert([
            ['code' => 'ahu', 'family' => 'air', 'name' => 'Air handling unit'],
            ['code' => 'fcu', 'family' => 'air', 'name' => 'Fan coil unit'],
            ['code' => 'vav', 'family' => 'air', 'name' => 'Variable air volume unit'],
            ['code' => 'fan', 'family' => 'air', 'name' => 'Fan'],
            ['code' => 'chiller', 'family' => 'thermal', 'name' => 'Chiller'],
            ['code' => 'boiler', 'family' => 'thermal', 'name' => 'Boiler'],
            ['code' => 'heat_pump', 'family' => 'thermal', 'name' => 'Heat pump'],
            ['code' => 'circulation_pump', 'family' => 'hydronic', 'name' => 'Circulation pump'],
            ['code' => 'motorized_valve', 'family' => 'hydronic', 'name' => 'Motorized valve'],
            ['code' => 'electrical_meter', 'family' => 'metering', 'name' => 'Electrical meter'],
            ['code' => 'water_meter', 'family' => 'metering', 'name' => 'Water meter'],
            ['code' => 'temperature_sensor', 'family' => 'instrumentation', 'name' => 'Temperature sensor'],
            ['code' => 'pressure_transmitter', 'family' => 'instrumentation', 'name' => 'Pressure transmitter'],
            ['code' => 'co2_sensor', 'family' => 'instrumentation', 'name' => 'CO2 sensor'],
            ['code' => 'ddc_controller', 'family' => 'controls_hardware', 'name' => 'DDC controller'],
            ['code' => 'gateway', 'family' => 'controls_hardware', 'name' => 'Gateway'],
            ['code' => 'other', 'family' => 'general', 'name' => 'Other'],
        ]);
        Schema::create('equipment', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignUuid('organization_id')->constrained()->restrictOnDelete();
            $table->foreignUuid('building_id')->constrained()->restrictOnDelete();
            $table->foreignUuid('floor_id')->nullable()->constrained()->restrictOnDelete();
            $table->foreignUuid('zone_id')->nullable()->constrained()->restrictOnDelete();
            $table->string('code', 64);
            $table->string('name');
            $table->text('description')->nullable();
            $table->string('type_code', 64);
            $table->foreign('type_code')->references('code')->on('equipment_types')->restrictOnDelete();
            $table->string('manufacturer')->nullable();
            $table->string('model')->nullable();
            $table->string('serial_number')->nullable();
            $table->string('lifecycle_status', 32)->default('planned');
            $table->date('installed_on')->nullable();
            $table->date('commissioned_on')->nullable();
            $table->jsonb('specifications')->nullable();
            $table->unsignedSmallInteger('spec_schema_version')->nullable();
            $table->timestampsTz();
            $table->unique(['building_id', 'code'], 'equipment_building_code_unique');
            $table->index(['organization_id', 'building_id', 'type_code', 'id'], 'equipment_type_listing_idx');
            $table->index(['organization_id', 'building_id', 'lifecycle_status', 'id'], 'equipment_status_listing_idx');
            $table->index(['organization_id', 'building_id', 'floor_id', 'id'], 'equipment_floor_listing_idx');
            $table->index(['organization_id', 'building_id', 'zone_id', 'id'], 'equipment_zone_listing_idx');
        });

        if (DB::getDriverName() === 'pgsql') {
            DB::statement('ALTER TABLE equipment ADD CONSTRAINT equipment_building_tenant_fk FOREIGN KEY (building_id, organization_id) REFERENCES buildings (id, organization_id) ON DELETE RESTRICT');
            DB::statement('ALTER TABLE equipment ADD CONSTRAINT equipment_floor_parent_fk FOREIGN KEY (floor_id, building_id, organization_id) REFERENCES floors (id, building_id, organization_id) ON DELETE RESTRICT');
            DB::statement('ALTER TABLE equipment ADD CONSTRAINT equipment_zone_parent_fk FOREIGN KEY (zone_id, floor_id, building_id, organization_id) REFERENCES zones (id, floor_id, building_id, organization_id) ON DELETE RESTRICT');
            DB::statement('ALTER TABLE equipment ADD CONSTRAINT equipment_zone_requires_floor CHECK (zone_id IS NULL OR floor_id IS NOT NULL)');
            DB::statement("ALTER TABLE equipment ADD CONSTRAINT equipment_code_canonical CHECK (code ~ '^[A-Z0-9][A-Z0-9_-]{0,63}$')");
            DB::statement("ALTER TABLE equipment ADD CONSTRAINT equipment_status_valid CHECK (lifecycle_status IN ('planned', 'installed', 'commissioned', 'active', 'out_of_service', 'retired'))");
            DB::statement('ALTER TABLE equipment ADD CONSTRAINT equipment_dates_ordered CHECK (installed_on IS NULL OR commissioned_on IS NULL OR commissioned_on >= installed_on)');
            DB::statement("ALTER TABLE equipment ADD CONSTRAINT equipment_specs_object CHECK ((specifications IS NULL AND spec_schema_version IS NULL) OR (specifications IS NOT NULL AND jsonb_typeof(specifications) = 'object' AND spec_schema_version IS NOT DISTINCT FROM 1))");
            DB::unprepared("CREATE OR REPLACE FUNCTION bms_reject_equipment_reparent() RETURNS trigger LANGUAGE plpgsql AS \$\$ BEGIN IF NEW.organization_id IS DISTINCT FROM OLD.organization_id OR NEW.building_id IS DISTINCT FROM OLD.building_id OR NEW.floor_id IS DISTINCT FROM OLD.floor_id OR NEW.zone_id IS DISTINCT FROM OLD.zone_id THEN RAISE EXCEPTION 'equipment reparenting is prohibited'; END IF; RETURN NEW; END; \$\$");
            DB::unprepared('CREATE TRIGGER equipment_no_reparent BEFORE UPDATE OF organization_id, building_id, floor_id, zone_id ON equipment FOR EACH ROW EXECUTE FUNCTION bms_reject_equipment_reparent()');
        } elseif (DB::getDriverName() === 'sqlite') {
            DB::unprepared("CREATE TRIGGER equipment_parent_insert BEFORE INSERT ON equipment WHEN NOT EXISTS (SELECT 1 FROM buildings WHERE id = NEW.building_id AND organization_id = NEW.organization_id) OR (NEW.floor_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM floors WHERE id = NEW.floor_id AND building_id = NEW.building_id AND organization_id = NEW.organization_id)) OR (NEW.zone_id IS NOT NULL AND (NEW.floor_id IS NULL OR NOT EXISTS (SELECT 1 FROM zones WHERE id = NEW.zone_id AND floor_id = NEW.floor_id AND building_id = NEW.building_id AND organization_id = NEW.organization_id))) BEGIN SELECT RAISE(ABORT, 'equipment parent mismatch'); END");
            DB::unprepared("CREATE TRIGGER equipment_no_reparent BEFORE UPDATE OF organization_id, building_id, floor_id, zone_id ON equipment WHEN NEW.organization_id != OLD.organization_id OR NEW.building_id != OLD.building_id OR NEW.floor_id IS NOT OLD.floor_id OR NEW.zone_id IS NOT OLD.zone_id BEGIN SELECT RAISE(ABORT, 'equipment reparenting is prohibited'); END");
            DB::unprepared("CREATE TRIGGER buildings_no_equipment_tenant_change BEFORE UPDATE OF organization_id ON buildings WHEN EXISTS (SELECT 1 FROM equipment WHERE building_id = OLD.id) BEGIN SELECT RAISE(ABORT, 'building with equipment cannot change organization'); END");
            DB::unprepared("CREATE TRIGGER equipment_values_insert BEFORE INSERT ON equipment WHEN NEW.code != upper(NEW.code) OR length(NEW.code) = 0 OR length(NEW.code) > 64 OR NEW.code GLOB '*[^A-Z0-9_-]*' OR substr(NEW.code, 1, 1) GLOB '[^A-Z0-9]' OR NEW.lifecycle_status NOT IN ('planned', 'installed', 'commissioned', 'active', 'out_of_service', 'retired') OR (NEW.installed_on IS NOT NULL AND NEW.commissioned_on IS NOT NULL AND NEW.commissioned_on < NEW.installed_on) OR (NEW.specifications IS NULL AND NEW.spec_schema_version IS NOT NULL) OR (NEW.specifications IS NOT NULL AND (NEW.spec_schema_version IS NOT 1 OR CASE WHEN json_valid(NEW.specifications) THEN json_type(NEW.specifications) != 'object' ELSE 1 END)) BEGIN SELECT RAISE(ABORT, 'invalid equipment values'); END");
            DB::unprepared("CREATE TRIGGER equipment_values_update BEFORE UPDATE ON equipment WHEN NEW.code != upper(NEW.code) OR length(NEW.code) = 0 OR length(NEW.code) > 64 OR NEW.code GLOB '*[^A-Z0-9_-]*' OR substr(NEW.code, 1, 1) GLOB '[^A-Z0-9]' OR NEW.lifecycle_status NOT IN ('planned', 'installed', 'commissioned', 'active', 'out_of_service', 'retired') OR (NEW.installed_on IS NOT NULL AND NEW.commissioned_on IS NOT NULL AND NEW.commissioned_on < NEW.installed_on) OR (NEW.specifications IS NULL AND NEW.spec_schema_version IS NOT NULL) OR (NEW.specifications IS NOT NULL AND (NEW.spec_schema_version IS NOT 1 OR CASE WHEN json_valid(NEW.specifications) THEN json_type(NEW.specifications) != 'object' ELSE 1 END)) BEGIN SELECT RAISE(ABORT, 'invalid equipment values'); END");
        } else {
            throw new RuntimeException('Equipment inventory requires PostgreSQL or SQLite.');
        }
    }

    public function down(): void
    {
        if (DB::getDriverName() === 'pgsql') {
            DB::statement('DROP TRIGGER IF EXISTS equipment_no_reparent ON equipment');
            DB::statement('DROP FUNCTION IF EXISTS bms_reject_equipment_reparent()');
        } elseif (DB::getDriverName() === 'sqlite') {
            foreach (['equipment_parent_insert', 'equipment_no_reparent', 'buildings_no_equipment_tenant_change',
                'equipment_values_insert', 'equipment_values_update'] as $trigger) {
                DB::statement("DROP TRIGGER IF EXISTS $trigger");
            }
        }
        Schema::dropIfExists('equipment');
        Schema::dropIfExists('equipment_types');
        Schema::table('zones', function (Blueprint $table): void {
            $table->dropUnique('zones_equipment_parent_unique');
        });
    }
};
