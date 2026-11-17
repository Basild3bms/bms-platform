<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class AuthControllerTest extends TestCase
{
    use RefreshDatabase;

    public function test_valid_credentials_issue_token_and_logout_revokes_it(): void
    {
        $user = User::factory()->create(['password' => 'correct-password']);

        $login = $this->postJson('/api/v1/auth/login', ['email' => $user->email, 'password' => 'correct-password']);

        $login->assertOk()->assertJsonPath('user.id', $user->id);
        $token = $login->json('token');
        $this->assertNotEmpty($token);
        $this->assertSame(['id', 'name', 'email'], array_keys($login->json('user')));
        $audit = DB::table('audit_events')->where('action', 'auth.login')->first();
        $this->assertStringNotContainsString($token, json_encode($audit));
        $this->assertStringNotContainsString('correct-password', json_encode($audit));
        $this->withToken($token)->getJson('/api/v1/auth/me')->assertOk()->assertJsonPath('id', $user->id);
        $this->withToken($token)->postJson('/api/v1/auth/logout')->assertOk();
        Auth::forgetGuards();
        $this->withToken($token)->getJson('/api/v1/auth/me')->assertUnauthorized();
        $this->assertDatabaseHas('audit_events', ['actor_user_id' => $user->id, 'action' => 'auth.logout']);
    }

    public function test_wrong_password_returns_401_without_token(): void
    {
        $user = User::factory()->create(['password' => 'correct-password']);

        $this->postJson('/api/v1/auth/login', ['email' => $user->email, 'password' => 'wrong-password'])
            ->assertUnauthorized()->assertJsonPath('message', 'Invalid credentials.');

        $this->assertDatabaseCount('personal_access_tokens', 0);
        $this->assertDatabaseHas('audit_events', ['actor_user_id' => $user->id, 'action' => 'auth.login_failed']);
    }

    public function test_repeated_failed_login_returns_429(): void
    {
        User::factory()->create(['email' => 'limited@example.test']);

        for ($attempt = 0; $attempt < 5; $attempt++) {
            $this->postJson('/api/v1/auth/login', ['email' => 'limited@example.test', 'password' => 'wrong'])
                ->assertUnauthorized();
        }

        $this->postJson('/api/v1/auth/login', ['email' => 'limited@example.test', 'password' => 'wrong'])
            ->assertTooManyRequests();
    }

    public function test_expired_token_returns_401(): void
    {
        $user = User::factory()->create();
        $token = $user->createToken('test', ['*'], now()->addMinute())->plainTextToken;
        $this->travel(2)->minutes();

        $this->withToken($token)->getJson('/api/v1/auth/me')->assertUnauthorized();
    }

    public function test_disabled_user_cannot_log_in_or_use_an_existing_token(): void
    {
        $user = User::factory()->create(['password' => 'correct-password']);
        $token = $user->createToken('test')->plainTextToken;
        DB::table('users')->where('id', $user->id)->update(['is_active' => false]);

        $this->postJson('/api/v1/auth/login', ['email' => $user->email, 'password' => 'correct-password'])
            ->assertUnauthorized();
        Auth::forgetGuards();
        $this->withToken($token)->getJson('/api/v1/auth/me')->assertUnauthorized();
    }

    public function test_web_session_cannot_use_bearer_only_routes(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user)->postJson('/api/v1/auth/logout')->assertUnauthorized();
        $this->actingAs($user)->getJson('/api/v1/auth/me')->assertUnauthorized();
    }

    public function test_many_email_guesses_from_one_ip_return_429(): void
    {
        for ($attempt = 0; $attempt < 20; $attempt++) {
            $this->postJson('/api/v1/auth/login', [
                'email' => "guess-$attempt@example.test", 'password' => 'wrong-password',
            ])->assertUnauthorized();
        }

        $this->postJson('/api/v1/auth/login', [
            'email' => 'next@example.test', 'password' => 'wrong-password',
        ])->assertTooManyRequests();
        $this->assertDatabaseHas('audit_events', ['action' => 'auth.login_limited']);
    }
}
