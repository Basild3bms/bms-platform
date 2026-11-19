<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::table('permissions')->insert([
            ['code' => 'buildings.view'],
            ['code' => 'buildings.manage'],
        ]);

        DB::table('role_permissions')->insert([
            ['role_code' => 'viewer', 'permission_code' => 'buildings.view'],
            ['role_code' => 'operator', 'permission_code' => 'buildings.view'],
            ['role_code' => 'admin', 'permission_code' => 'buildings.view'],
            ['role_code' => 'owner', 'permission_code' => 'buildings.view'],
            ['role_code' => 'admin', 'permission_code' => 'buildings.manage'],
            ['role_code' => 'owner', 'permission_code' => 'buildings.manage'],
        ]);
    }

    public function down(): void
    {
        DB::table('role_permissions')->whereIn('permission_code', [
            'buildings.view', 'buildings.manage',
        ])->delete();
        DB::table('permissions')->whereIn('code', [
            'buildings.view', 'buildings.manage',
        ])->delete();
    }
};
