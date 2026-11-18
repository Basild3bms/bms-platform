<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Str;
use Laravel\Sanctum\NewAccessToken;

class AuthController extends Controller
{
    private static ?string $dummyPasswordHash = null;

    public function login(Request $request): JsonResponse
    {
        $credentials = $request->validate([
            'email' => ['required', 'email', 'max:255'],
            'password' => ['required', 'string'],
        ]);
        $email = Str::lower(trim($credentials['email']));
        $key = 'login:'.hash('sha256', $email.'|'.$request->ip());
        $ipKey = 'login-ip:'.hash('sha256', (string) $request->ip());
        if (RateLimiter::tooManyAttempts($key, 5) || RateLimiter::tooManyAttempts($ipKey, 20)) {
            DB::table('audit_events')->insert([
                'id' => (string) Str::uuid(), 'action' => 'auth.login_limited',
                'ip_address' => $request->ip(), 'created_at' => now(),
            ]);

            return response()->json(['message' => 'Too many login attempts.'], 429);
        }

        $user = User::where('email', $email)->first();
        $passwordMatches = Hash::check(
            $credentials['password'],
            $user?->password ?? (self::$dummyPasswordHash ??= Hash::make(Str::random(32))),
        );
        if ($user === null || ! $user->is_active || ! $passwordMatches) {
            RateLimiter::hit($key, 60);
            RateLimiter::hit($ipKey, 60);
            DB::table('audit_events')->insert([
                'id' => (string) Str::uuid(), 'action' => 'auth.login_failed',
                'actor_user_id' => $user?->id,
                'ip_address' => $request->ip(), 'created_at' => now(),
            ]);

            return response()->json(['message' => 'Invalid credentials.'], 401);
        }
        RateLimiter::clear($key);
        $token = DB::transaction(function () use ($request, $user): NewAccessToken {
            $token = $user->createToken('api', ['*'], now()->addHours(12));
            $this->audit($request, $user, 'auth.login');

            return $token;
        });

        return response()->json([
            'token' => $token->plainTextToken,
            'token_type' => 'Bearer',
            'expires_at' => $token->accessToken->expires_at,
            'user' => $user->only(['id', 'name', 'email']),
        ]);
    }

    public function me(Request $request): JsonResponse
    {
        return response()->json($request->user()->only(['id', 'name', 'email']));
    }

    public function organizations(Request $request): JsonResponse
    {
        $memberships = DB::table('organization_memberships as m')
            ->join('organizations as o', 'o.id', '=', 'm.organization_id')
            ->leftJoin('role_permissions as rp', 'rp.role_code', '=', 'm.role')
            ->where('m.user_id', $request->user()->id)
            ->where('m.active', true)
            ->select('o.id', 'o.name', 'm.role', 'rp.permission_code')
            ->orderBy('o.name')->orderBy('o.id')->orderBy('rp.permission_code')
            ->get();

        $organizations = [];
        foreach ($memberships as $membership) {
            if (! isset($organizations[$membership->id])) {
                $organizations[$membership->id] = [
                    'id' => $membership->id,
                    'name' => $membership->name,
                    'role' => $membership->role,
                    'permissions' => [],
                ];
            }
            if ($membership->permission_code !== null) {
                $organizations[$membership->id]['permissions'][] = $membership->permission_code;
            }
        }

        return response()->json(['data' => array_values($organizations)]);
    }

    public function logout(Request $request): JsonResponse
    {
        $user = $request->user();
        DB::transaction(function () use ($request, $user): void {
            $user->currentAccessToken()->delete();
            $this->audit($request, $user, 'auth.logout');
        });

        return response()->json(['message' => 'Logged out.']);
    }

    private function audit(Request $request, User $user, string $action): void
    {
        DB::table('audit_events')->insert([
            'id' => (string) Str::uuid(), 'actor_user_id' => $user->id,
            'action' => $action, 'ip_address' => $request->ip(), 'created_at' => now(),
        ]);
    }
}
