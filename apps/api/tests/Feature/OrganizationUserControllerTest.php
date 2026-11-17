<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Tests\TestCase;

class OrganizationUserControllerTest extends TestCase
{
    use RefreshDatabase;

    private function organization(): string
    {
        $id = (string) Str::uuid();
        DB::table('organizations')->insert(['id' => $id, 'name' => 'Test', 'slug' => $id, 'timezone' => 'UTC']);

        return $id;
    }

    private function member(string $organizationId, string $role): User
    {
        $user = User::factory()->create();
        DB::table('organization_memberships')->insert([
            'id' => (string) Str::uuid(), 'organization_id' => $organizationId,
            'user_id' => $user->id, 'role' => $role, 'active' => true,
        ]);

        return $user;
    }

    private function authenticate(User $user): void
    {
        $this->withToken($user->createToken('test')->plainTextToken);
    }

    public function test_foreign_tenant_returns_404_for_member_listing(): void
    {
        $own = $this->organization();
        $foreign = $this->organization();
        $admin = $this->member($own, 'owner');
        $this->member($foreign, 'viewer');

        $this->authenticate($admin);
        $this->getJson("/api/v1/organizations/$foreign/users")->assertNotFound();
    }

    public function test_anonymous_member_listing_returns_401(): void
    {
        $organization = $this->organization();

        $this->getJson("/api/v1/organizations/$organization/users")->assertUnauthorized();
    }

    public function test_bearer_token_can_list_only_its_organization_members(): void
    {
        $own = $this->organization();
        $foreign = $this->organization();
        $admin = $this->member($own, 'admin');
        $other = $this->member($foreign, 'viewer');
        $token = $admin->createToken('test')->plainTextToken;

        $this->withToken($token)->getJson("/api/v1/organizations/$own/users")
            ->assertOk()->assertJsonCount(1, 'data')->assertJsonPath('data.0.email', $admin->email);
        $this->withToken($token)->getJson("/api/v1/organizations/$foreign/users")->assertNotFound();
    }

    public function test_viewer_cannot_create_users(): void
    {
        $organization = $this->organization();
        $viewer = $this->member($organization, 'viewer');

        $this->authenticate($viewer);
        $this->postJson("/api/v1/organizations/$organization/users", [
            'name' => 'New User', 'email' => 'new@example.test', 'password' => 'safe-password-123', 'role' => 'owner',
        ])->assertForbidden();

        $this->assertDatabaseMissing('users', ['email' => 'new@example.test']);
    }

    public function test_admin_cannot_grant_owner_role(): void
    {
        $organization = $this->organization();
        $admin = $this->member($organization, 'admin');

        $this->authenticate($admin);
        $this->postJson("/api/v1/organizations/$organization/users", [
            'name' => 'New User', 'email' => 'new@example.test', 'password' => 'safe-password-123', 'role' => 'owner',
        ])->assertForbidden();

        $this->assertDatabaseMissing('users', ['email' => 'new@example.test']);
    }

    public function test_invalid_role_returns_422_without_creating_user(): void
    {
        $organization = $this->organization();
        $owner = $this->member($organization, 'owner');
        $this->authenticate($owner);

        $this->postJson("/api/v1/organizations/$organization/users", [
            'name' => 'New User', 'email' => 'new@example.test',
            'password' => 'safe-password-123', 'role' => 'superuser',
        ])->assertUnprocessable()->assertJsonValidationErrors('role');

        $this->assertDatabaseMissing('users', ['email' => 'new@example.test']);
    }

    public function test_owner_creates_user_membership_and_audit_event(): void
    {
        $organization = $this->organization();
        $owner = $this->member($organization, 'owner');

        $this->authenticate($owner);
        $response = $this->postJson("/api/v1/organizations/$organization/users", [
            'name' => 'New User', 'email' => 'NEW@example.test', 'password' => 'safe-password-123', 'role' => 'viewer',
            'is_active' => false, 'email_verified_at' => now()->toISOString(),
        ]);
        $response->assertCreated()->assertJsonPath('user.email', 'new@example.test');
        $this->assertSame(['id', 'name', 'email'], array_keys($response->json('user')));

        $this->assertDatabaseHas('organization_memberships', ['organization_id' => $organization, 'role' => 'viewer', 'active' => true]);
        $this->assertDatabaseHas('audit_events', ['organization_id' => $organization, 'actor_user_id' => $owner->id, 'action' => 'membership.created']);
        $created = User::where('email', 'new@example.test')->firstOrFail();
        $this->assertTrue($created->is_active);
        $this->assertNull($created->email_verified_at);
        $this->assertTrue(Hash::check('safe-password-123', $created->password));
        $audit = DB::table('audit_events')->where('action', 'membership.created')->first();
        $this->assertStringNotContainsString('safe-password-123', json_encode($audit));
    }

    public function test_revoked_member_cannot_access_organization(): void
    {
        $organization = $this->organization();
        $viewer = $this->member($organization, 'viewer');
        DB::table('organization_memberships')->where('user_id', $viewer->id)->update(['active' => false]);

        $this->authenticate($viewer);
        $this->getJson("/api/v1/organizations/$organization/users")->assertNotFound();
    }

    public function test_owner_can_change_and_revoke_lower_role_with_audit(): void
    {
        $organization = $this->organization();
        $owner = $this->member($organization, 'owner');
        $operator = $this->member($organization, 'operator');
        $membership = DB::table('organization_memberships')->where('user_id', $operator->id)->value('id');

        $this->authenticate($owner);
        $this->patchJson("/api/v1/organizations/$organization/memberships/$membership", ['role' => 'viewer'])
            ->assertOk()->assertJsonPath('role', 'viewer');
        $this->assertDatabaseHas('organization_memberships', ['id' => $membership, 'role' => 'viewer']);
        $this->assertDatabaseHas('audit_events', ['subject_id' => $membership, 'action' => 'membership.role_updated']);

        $this->deleteJson("/api/v1/organizations/$organization/memberships/$membership")->assertOk();
        $this->assertDatabaseHas('organization_memberships', ['id' => $membership, 'active' => false]);
        $this->assertDatabaseHas('audit_events', ['subject_id' => $membership, 'action' => 'membership.revoked']);
    }

    public function test_foreign_tenant_membership_update_returns_404(): void
    {
        $own = $this->organization();
        $foreign = $this->organization();
        $owner = $this->member($own, 'owner');
        $target = $this->member($foreign, 'viewer');
        $membership = DB::table('organization_memberships')->where('user_id', $target->id)->value('id');

        $this->authenticate($owner);
        $this->patchJson("/api/v1/organizations/$own/memberships/$membership", ['role' => 'operator'])
            ->assertNotFound();
        $this->assertDatabaseHas('organization_memberships', ['id' => $membership, 'role' => 'viewer']);
    }

    public function test_last_owner_cannot_be_demoted_or_removed(): void
    {
        $organization = $this->organization();
        $owner = $this->member($organization, 'owner');
        $membership = DB::table('organization_memberships')->where('user_id', $owner->id)->value('id');
        $this->authenticate($owner);

        $this->patchJson("/api/v1/organizations/$organization/memberships/$membership", ['role' => 'viewer'])
            ->assertForbidden();
        $this->deleteJson("/api/v1/organizations/$organization/memberships/$membership")
            ->assertForbidden();

        $this->assertDatabaseHas('organization_memberships', ['id' => $membership, 'role' => 'owner', 'active' => true]);
    }

    public function test_foreign_tenant_membership_revocation_returns_404(): void
    {
        $own = $this->organization();
        $foreign = $this->organization();
        $owner = $this->member($own, 'owner');
        $target = $this->member($foreign, 'viewer');
        $membership = DB::table('organization_memberships')->where('user_id', $target->id)->value('id');
        $this->authenticate($owner);

        $this->deleteJson("/api/v1/organizations/$own/memberships/$membership")->assertNotFound();

        $this->assertDatabaseHas('organization_memberships', ['id' => $membership, 'active' => true]);
    }
}
