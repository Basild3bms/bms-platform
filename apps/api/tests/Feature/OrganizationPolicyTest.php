<?php

namespace Tests\Feature;

use App\Models\Organization;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Str;
use Tests\TestCase;

class OrganizationPolicyTest extends TestCase
{
    use RefreshDatabase;

    public function test_role_permissions_and_grant_rank_are_enforced(): void
    {
        $organizationId = (string) Str::uuid();
        DB::table('organizations')->insert(['id' => $organizationId, 'name' => 'Test', 'slug' => $organizationId, 'timezone' => 'UTC']);
        $organization = Organization::findOrFail($organizationId);

        foreach (['viewer', 'operator', 'admin', 'owner'] as $role) {
            $user = User::factory()->create();
            DB::table('organization_memberships')->insert([
                'id' => (string) Str::uuid(), 'organization_id' => $organizationId,
                'user_id' => $user->id, 'role' => $role, 'active' => true,
            ]);

            $canManage = Gate::forUser($user)->allows('manageMembers', $organization);
            $this->assertSame(in_array($role, ['admin', 'owner'], true), $canManage);
            $this->assertSame($role === 'owner', Gate::forUser($user)->allows('assignRole', [$organization, 'admin']));
            $this->assertSame($canManage, Gate::forUser($user)->allows('assignRole', [$organization, 'viewer']));
            $this->assertFalse(Gate::forUser($user)->allows('assignRole', [$organization, 'owner']));
        }

        $outsider = User::factory()->create();
        $this->assertFalse(Gate::forUser($outsider)->allows('viewMembers', $organization));
    }
}
