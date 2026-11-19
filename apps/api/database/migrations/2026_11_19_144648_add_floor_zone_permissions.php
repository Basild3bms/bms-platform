<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::table('permissions')->insert([
            ['code' => 'floors.view'], ['code' => 'floors.manage'],
            ['code' => 'zones.view'], ['code' => 'zones.manage'],
        ]);
        $rows = [];
        foreach (['viewer', 'operator', 'admin', 'owner'] as $role) {
            foreach (['floors.view', 'zones.view'] as $permission) {
                $rows[] = ['role_code' => $role, 'permission_code' => $permission];
            }
            if (in_array($role, ['admin', 'owner'], true)) {
                foreach (['floors.manage', 'zones.manage'] as $permission) {
                    $rows[] = ['role_code' => $role, 'permission_code' => $permission];
                }
            }
        }
        DB::table('role_permissions')->insert($rows);
    }

    public function down(): void
    {
        $permissions = ['floors.view', 'floors.manage', 'zones.view', 'zones.manage'];
        DB::table('role_permissions')->whereIn('permission_code', $permissions)->delete();
        DB::table('permissions')->whereIn('code', $permissions)->delete();
    }
};
