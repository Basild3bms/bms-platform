<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (DB::table('devices as d')->join('buildings as b', 'b.id', '=', 'd.building_id')
            ->whereColumn('d.organization_id', '!=', 'b.organization_id')->exists()) {
            throw new RuntimeException('Existing devices reference buildings in another organization; repair before migrating.');
        }

        Schema::create('organization_invitations', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignUuid('organization_id')->constrained()->cascadeOnDelete();
            $table->foreignId('invited_by_user_id')->constrained('users')->restrictOnDelete();
            $table->string('email');
            $table->string('name');
            $table->string('role');
            $table->foreign('role')->references('code')->on('roles');
            $table->string('token_hash', 64)->unique();
            $table->timestampTz('expires_at');
            $table->timestampTz('accepted_at')->nullable();
            $table->timestampsTz();
            $table->index(['organization_id', 'email']);
        });
        Schema::table('organization_memberships', function (Blueprint $table): void {
            $table->index(['organization_id', 'active', 'role'], 'memberships_listing_idx');
        });

        if (DB::getDriverName() === 'pgsql') {
            DB::statement('ALTER TABLE buildings ADD CONSTRAINT buildings_id_organization_unique UNIQUE (id, organization_id)');
            DB::statement('ALTER TABLE devices ADD CONSTRAINT devices_building_organization_fk FOREIGN KEY (building_id, organization_id) REFERENCES buildings (id, organization_id)');
            DB::unprepared("CREATE OR REPLACE FUNCTION bms_reject_audit_change() RETURNS trigger LANGUAGE plpgsql AS \$\$ BEGIN RAISE EXCEPTION 'audit_events is append only'; END; \$\$");
            DB::unprepared('CREATE TRIGGER audit_events_immutable BEFORE UPDATE OR DELETE ON audit_events FOR EACH ROW EXECUTE FUNCTION bms_reject_audit_change()');
            DB::unprepared('CREATE TRIGGER audit_events_no_truncate BEFORE TRUNCATE ON audit_events FOR EACH STATEMENT EXECUTE FUNCTION bms_reject_audit_change()');
        } elseif (DB::getDriverName() === 'sqlite') {
            DB::unprepared("CREATE TRIGGER devices_tenant_insert BEFORE INSERT ON devices WHEN NOT EXISTS (SELECT 1 FROM buildings WHERE id = NEW.building_id AND organization_id = NEW.organization_id) BEGIN SELECT RAISE(ABORT, 'device building tenant mismatch'); END");
            DB::unprepared("CREATE TRIGGER devices_tenant_update BEFORE UPDATE OF building_id, organization_id ON devices WHEN NOT EXISTS (SELECT 1 FROM buildings WHERE id = NEW.building_id AND organization_id = NEW.organization_id) BEGIN SELECT RAISE(ABORT, 'device building tenant mismatch'); END");
            DB::unprepared("CREATE TRIGGER buildings_tenant_update BEFORE UPDATE OF organization_id ON buildings WHEN EXISTS (SELECT 1 FROM devices WHERE building_id = OLD.id AND organization_id != NEW.organization_id) BEGIN SELECT RAISE(ABORT, 'building has devices in another tenant'); END");
            DB::unprepared("CREATE TRIGGER audit_events_immutable_update BEFORE UPDATE ON audit_events BEGIN SELECT RAISE(ABORT, 'audit_events is append only'); END");
            DB::unprepared("CREATE TRIGGER audit_events_immutable_delete BEFORE DELETE ON audit_events BEGIN SELECT RAISE(ABORT, 'audit_events is append only'); END");
        } else {
            throw new RuntimeException('M2.1 hardening requires PostgreSQL or SQLite.');
        }
    }

    public function down(): void
    {
        if (DB::getDriverName() === 'pgsql') {
            DB::statement('DROP TRIGGER IF EXISTS audit_events_immutable ON audit_events');
            DB::statement('DROP TRIGGER IF EXISTS audit_events_no_truncate ON audit_events');
            DB::statement('DROP FUNCTION IF EXISTS bms_reject_audit_change()');
            DB::statement('ALTER TABLE devices DROP CONSTRAINT IF EXISTS devices_building_organization_fk');
            DB::statement('ALTER TABLE buildings DROP CONSTRAINT IF EXISTS buildings_id_organization_unique');
        } elseif (DB::getDriverName() === 'sqlite') {
            foreach (['devices_tenant_insert', 'devices_tenant_update', 'buildings_tenant_update', 'audit_events_immutable_update', 'audit_events_immutable_delete'] as $trigger) {
                DB::statement("DROP TRIGGER IF EXISTS $trigger");
            }
        }

        Schema::dropIfExists('organization_invitations');
        DB::statement('DROP INDEX IF EXISTS memberships_listing_idx');
    }
};
