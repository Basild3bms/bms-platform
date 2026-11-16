<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('organizations', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('name');
            $table->string('slug')->unique();
            $table->string('timezone')->default('UTC');
            $table->timestampsTz();
        });

        Schema::create('buildings', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('organization_id')->constrained()->cascadeOnDelete();
            $table->string('name');
            $table->string('code');
            $table->string('address')->nullable();
            $table->string('timezone');
            $table->timestampsTz();
            $table->unique(['organization_id', 'code']);
        });

        Schema::create('devices', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('organization_id')->constrained()->cascadeOnDelete();
            $table->foreignUuid('building_id')->constrained()->cascadeOnDelete();
            $table->string('name');
            $table->string('protocol');
            $table->string('external_id');
            $table->string('equipment_type')->nullable();
            $table->string('status')->default('unknown');
            $table->timestampsTz();
            $table->unique(['building_id', 'protocol', 'external_id']);
        });

        Schema::create('device_points', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('device_id')->constrained()->cascadeOnDelete();
            $table->string('name');
            $table->string('external_id');
            $table->string('kind');
            $table->string('unit')->nullable();
            $table->boolean('writable')->default(false);
            $table->timestampsTz();
            $table->unique(['device_id', 'external_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('device_points');
        Schema::dropIfExists('devices');
        Schema::dropIfExists('buildings');
        Schema::dropIfExists('organizations');
    }
};
