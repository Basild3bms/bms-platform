<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('roles', function (Blueprint $table) {
            $table->string('code')->primary();
            $table->unsignedSmallInteger('rank');
        });
        Schema::create('permissions', function (Blueprint $table) {
            $table->string('code')->primary();
        });
        Schema::create('role_permissions', function (Blueprint $table) {
            $table->string('role_code');
            $table->string('permission_code');
            $table->primary(['role_code', 'permission_code']);
            $table->foreign('role_code')->references('code')->on('roles')->cascadeOnDelete();
            $table->foreign('permission_code')->references('code')->on('permissions')->cascadeOnDelete();
        });
        Schema::create('organization_memberships', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('organization_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('role');
            $table->foreign('role')->references('code')->on('roles');
            $table->boolean('active')->default(true);
            $table->timestampsTz();
            $table->unique(['organization_id', 'user_id']);
            $table->index(['user_id', 'active']);
        });
        Schema::create('audit_events', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('organization_id')->nullable()->constrained()->restrictOnDelete();
            $table->foreignId('actor_user_id')->nullable()->constrained('users')->restrictOnDelete();
            $table->string('action');
            $table->string('subject_type')->nullable();
            $table->string('subject_id')->nullable();
            $table->ipAddress('ip_address')->nullable();
            $table->timestampTz('created_at')->useCurrent();
            $table->index(['organization_id', 'created_at']);
            $table->index(['actor_user_id', 'created_at']);
        });

        DB::table('roles')->insert([
            ['code' => 'viewer', 'rank' => 1], ['code' => 'operator', 'rank' => 2],
            ['code' => 'admin', 'rank' => 3], ['code' => 'owner', 'rank' => 4],
        ]);
        DB::table('permissions')->insert([
            ['code' => 'users.view'], ['code' => 'users.manage'], ['code' => 'roles.manage'],
        ]);
        DB::table('role_permissions')->insert([
            ['role_code' => 'admin', 'permission_code' => 'users.view'],
            ['role_code' => 'admin', 'permission_code' => 'users.manage'],
            ['role_code' => 'owner', 'permission_code' => 'users.view'],
            ['role_code' => 'owner', 'permission_code' => 'users.manage'],
            ['role_code' => 'owner', 'permission_code' => 'roles.manage'],
        ]);
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('audit_events');
        Schema::dropIfExists('organization_memberships');
        Schema::dropIfExists('role_permissions');
        Schema::dropIfExists('permissions');
        Schema::dropIfExists('roles');
    }
};
