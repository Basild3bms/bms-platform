<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class DatabaseDriverTest extends TestCase
{
    public function test_suite_uses_expected_database_driver(): void
    {
        $expected = getenv('BMS_EXPECT_DB_DRIVER');
        if ($expected === false) {
            $this->markTestSkipped('Set BMS_EXPECT_DB_DRIVER to assert CI database selection.');
        }

        $this->assertSame($expected, DB::connection()->getDriverName());
    }
}
