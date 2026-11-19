<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('floors', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignUuid('organization_id')->constrained()->restrictOnDelete();
            $table->foreignUuid('building_id')->constrained()->restrictOnDelete();
            $table->string('name');
            $table->string('code', 64);
            $table->integer('level');
            $table->timestampsTz();
            $table->unique(['building_id', 'code']);
            $table->unique(['id', 'building_id', 'organization_id'], 'floors_parent_identity_unique');
        });

        Schema::create('zones', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignUuid('organization_id')->constrained()->restrictOnDelete();
            $table->foreignUuid('building_id')->constrained()->restrictOnDelete();
            $table->foreignUuid('floor_id')->constrained()->restrictOnDelete();
            $table->string('name');
            $table->string('code', 64);
            $table->string('zone_type', 32);
            $table->timestampsTz();
            $table->unique(['floor_id', 'code']);
            $table->index(['organization_id', 'building_id', 'floor_id']);
        });

        if (DB::getDriverName() === 'pgsql') {
            DB::statement('ALTER TABLE floors ADD CONSTRAINT floors_building_tenant_fk FOREIGN KEY (building_id, organization_id) REFERENCES buildings (id, organization_id) ON DELETE RESTRICT');
            DB::statement('ALTER TABLE zones ADD CONSTRAINT zones_floor_parent_fk FOREIGN KEY (floor_id, building_id, organization_id) REFERENCES floors (id, building_id, organization_id) ON DELETE RESTRICT');
            DB::unprepared("CREATE OR REPLACE FUNCTION bms_reject_floor_reparent() RETURNS trigger LANGUAGE plpgsql AS \$\$ BEGIN IF NEW.building_id IS DISTINCT FROM OLD.building_id OR NEW.organization_id IS DISTINCT FROM OLD.organization_id THEN RAISE EXCEPTION 'floor reparenting is prohibited'; END IF; RETURN NEW; END; \$\$");
            DB::unprepared('CREATE TRIGGER floors_no_reparent BEFORE UPDATE OF building_id, organization_id ON floors FOR EACH ROW EXECUTE FUNCTION bms_reject_floor_reparent()');
            DB::unprepared("CREATE OR REPLACE FUNCTION bms_reject_zone_reparent() RETURNS trigger LANGUAGE plpgsql AS \$\$ BEGIN IF NEW.floor_id IS DISTINCT FROM OLD.floor_id OR NEW.building_id IS DISTINCT FROM OLD.building_id OR NEW.organization_id IS DISTINCT FROM OLD.organization_id THEN RAISE EXCEPTION 'zone reparenting is prohibited'; END IF; RETURN NEW; END; \$\$");
            DB::unprepared('CREATE TRIGGER zones_no_reparent BEFORE UPDATE OF floor_id, building_id, organization_id ON zones FOR EACH ROW EXECUTE FUNCTION bms_reject_zone_reparent()');
        } elseif (DB::getDriverName() === 'sqlite') {
            DB::unprepared("CREATE TRIGGER floors_parent_insert BEFORE INSERT ON floors WHEN NOT EXISTS (SELECT 1 FROM buildings WHERE id = NEW.building_id AND organization_id = NEW.organization_id) BEGIN SELECT RAISE(ABORT, 'floor building tenant mismatch'); END");
            DB::unprepared("CREATE TRIGGER floors_no_reparent BEFORE UPDATE OF building_id, organization_id ON floors WHEN NEW.building_id != OLD.building_id OR NEW.organization_id != OLD.organization_id BEGIN SELECT RAISE(ABORT, 'floor reparenting is prohibited'); END");
            DB::unprepared("CREATE TRIGGER zones_parent_insert BEFORE INSERT ON zones WHEN NOT EXISTS (SELECT 1 FROM floors WHERE id = NEW.floor_id AND building_id = NEW.building_id AND organization_id = NEW.organization_id) BEGIN SELECT RAISE(ABORT, 'zone floor parent mismatch'); END");
            DB::unprepared("CREATE TRIGGER zones_no_reparent BEFORE UPDATE OF floor_id, building_id, organization_id ON zones WHEN NEW.floor_id != OLD.floor_id OR NEW.building_id != OLD.building_id OR NEW.organization_id != OLD.organization_id BEGIN SELECT RAISE(ABORT, 'zone reparenting is prohibited'); END");
            DB::unprepared("CREATE TRIGGER buildings_no_floor_tenant_change BEFORE UPDATE OF organization_id ON buildings WHEN EXISTS (SELECT 1 FROM floors WHERE building_id = OLD.id) BEGIN SELECT RAISE(ABORT, 'building with floors cannot change organization'); END");
        } else {
            throw new RuntimeException('Floor and zone hierarchy requires PostgreSQL or SQLite.');
        }
    }

    public function down(): void
    {
        if (DB::getDriverName() === 'pgsql') {
            DB::statement('DROP TRIGGER IF EXISTS zones_no_reparent ON zones');
            DB::statement('DROP TRIGGER IF EXISTS floors_no_reparent ON floors');
            DB::statement('DROP FUNCTION IF EXISTS bms_reject_zone_reparent()');
            DB::statement('DROP FUNCTION IF EXISTS bms_reject_floor_reparent()');
        } elseif (DB::getDriverName() === 'sqlite') {
            foreach (['floors_parent_insert', 'floors_no_reparent', 'zones_parent_insert',
                'zones_no_reparent', 'buildings_no_floor_tenant_change'] as $trigger) {
                DB::statement("DROP TRIGGER IF EXISTS $trigger");
            }
        }
        Schema::dropIfExists('zones');
        Schema::dropIfExists('floors');
    }
};
