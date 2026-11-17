<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

class IdentitySchemaTest extends TestCase
{
    use RefreshDatabase;

    private function organization(): string
    {
        $id = (string) Str::uuid();
        DB::table('organizations')->insert(['id' => $id, 'name' => 'Test', 'slug' => $id, 'timezone' => 'UTC']);

        return $id;
    }

    public function test_membership_cannot_reference_another_unrecognized_organization(): void
    {
        $user = User::factory()->create();

        $this->expectException(QueryException::class);
        DB::table('organization_memberships')->insert([
            'id' => (string) Str::uuid(), 'organization_id' => (string) Str::uuid(),
            'user_id' => $user->id, 'role' => 'viewer',
        ]);
    }

    public function test_duplicate_organization_membership_is_rejected(): void
    {
        $organization = $this->organization();
        $user = User::factory()->create();
        DB::table('organization_memberships')->insert([
            'id' => (string) Str::uuid(), 'organization_id' => $organization,
            'user_id' => $user->id, 'role' => 'viewer',
        ]);

        $this->expectException(QueryException::class);
        DB::table('organization_memberships')->insert([
            'id' => (string) Str::uuid(), 'organization_id' => $organization,
            'user_id' => $user->id, 'role' => 'admin',
        ]);
    }

    public function test_organization_deletion_cascades_membership_without_audit(): void
    {
        $organization = $this->organization();
        $user = User::factory()->create();
        $membership = (string) Str::uuid();
        DB::table('organization_memberships')->insert([
            'id' => $membership, 'organization_id' => $organization,
            'user_id' => $user->id, 'role' => 'viewer',
        ]);

        DB::table('organizations')->where('id', $organization)->delete();

        $this->assertDatabaseMissing('organization_memberships', ['id' => $membership]);
    }

    public function test_audited_organization_cannot_be_deleted(): void
    {
        $organization = $this->organization();
        DB::table('audit_events')->insert([
            'id' => (string) Str::uuid(), 'organization_id' => $organization,
            'action' => 'organization.test', 'created_at' => now(),
        ]);

        $this->expectException(QueryException::class);
        DB::table('organizations')->where('id', $organization)->delete();
    }
}
