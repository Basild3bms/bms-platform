<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::table('permissions')->insert([['code' => 'equipment.view'], ['code' => 'equipment.manage']]);
        $rows = [];
        foreach (['viewer', 'operator', 'admin', 'owner'] as $role) {
            $rows[] = ['role_code' => $role, 'permission_code' => 'equipment.view'];
            if (in_array($role, ['admin', 'owner'], true)) {
                $rows[] = ['role_code' => $role, 'permission_code' => 'equipment.manage'];
            }
        }
        DB::table('role_permissions')->insert($rows);
    }

    public function down(): void
    {
        DB::table('role_permissions')->whereIn('permission_code', ['equipment.view', 'equipment.manage'])->delete();
        DB::table('permissions')->whereIn('code', ['equipment.view', 'equipment.manage'])->delete();
    }
};
