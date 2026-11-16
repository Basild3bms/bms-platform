<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

class CoreSchemaTest extends TestCase
{
    use RefreshDatabase;

    public function test_status_endpoint_is_available(): void
    {
        $this->getJson('/api/v1/status')->assertOk()->assertJsonPath('service', 'bms-api');
    }

    public function test_core_relationships_and_safe_point_default(): void
    {
        $organization = (string) Str::uuid();
        $building = (string) Str::uuid();
        $device = (string) Str::uuid();
        $point = (string) Str::uuid();

        DB::table('organizations')->insert(['id' => $organization, 'name' => 'Demo', 'slug' => 'demo']);
        DB::table('buildings')->insert(['id' => $building, 'organization_id' => $organization, 'name' => 'HQ', 'code' => 'HQ', 'timezone' => 'UTC']);
        DB::table('devices')->insert(['id' => $device, 'organization_id' => $organization, 'building_id' => $building, 'name' => 'AHU', 'protocol' => 'bacnet', 'external_id' => 'ahu-1']);
        DB::table('device_points')->insert(['id' => $point, 'device_id' => $device, 'name' => 'Temperature', 'external_id' => 'av-1', 'kind' => 'analog']);

        $this->assertSame(0, DB::table('device_points')->where('id', $point)->value('writable'));
        $this->assertSame(1, DB::table('devices')->where('building_id', $building)->count());
    }
}
