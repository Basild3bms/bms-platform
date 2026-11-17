<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class BootstrapOrganizationTest extends TestCase
{
    use RefreshDatabase;

    public function test_local_bootstrap_creates_owner_without_default_password(): void
    {
        $this->artisan('bms:bootstrap-organization', [
            '--name' => 'Example', '--slug' => 'example', '--email' => 'owner@example.test',
        ])->expectsQuestion('Owner password', 'safe-password-123')->assertExitCode(0);

        $this->assertDatabaseHas('organizations', ['slug' => 'example']);
        $this->assertDatabaseHas('users', ['email' => 'owner@example.test']);
        $this->assertDatabaseHas('organization_memberships', ['role' => 'owner', 'active' => true]);
        $this->assertDatabaseHas('audit_events', ['action' => 'organization.bootstrapped']);
    }
}
