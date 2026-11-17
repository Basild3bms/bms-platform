<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Organization;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class InvitationController extends Controller
{
    public function accept(Request $request): JsonResponse
    {
        $data = $request->validate([
            'token' => ['required', 'string', 'size:64'],
            'email' => ['required', 'email', 'max:255'],
            'password' => ['required', 'string', 'min:12', 'max:128'],
        ]);
        $email = Str::lower(trim($data['email']));

        $user = DB::transaction(function () use ($request, $data, $email): ?User {
            $invitation = DB::table('organization_invitations')
                ->where('token_hash', hash('sha256', $data['token']))->lockForUpdate()->first();
            if ($invitation === null || $invitation->email !== $email || $invitation->accepted_at !== null
                || now()->greaterThan($invitation->expires_at)) {
                return null;
            }

            $organization = Organization::find($invitation->organization_id);
            $inviter = User::find($invitation->invited_by_user_id);
            if ($organization === null || $inviter === null || ! Gate::forUser($inviter)->allows('assignRole', [$organization, $invitation->role])) {
                return null;
            }

            $user = User::where('email', $email)->first();
            if ($user !== null && (! $user->is_active || ! Hash::check($data['password'], $user->password))) {
                return null;
            }
            if ($user === null) {
                $user = User::create(['name' => $invitation->name, 'email' => $email, 'password' => $data['password']]);
            }
            $existing = DB::table('organization_memberships')
                ->where('organization_id', $organization->id)->where('user_id', $user->id)->first();
            if ($existing !== null && $existing->active) {
                return null;
            }
            $membershipId = $existing?->id ?? (string) Str::uuid();
            if ($existing === null) {
                DB::table('organization_memberships')->insert([
                    'id' => $membershipId, 'organization_id' => $organization->id,
                    'user_id' => $user->id, 'role' => $invitation->role, 'active' => true,
                    'created_at' => now(), 'updated_at' => now(),
                ]);
            } else {
                DB::table('organization_memberships')->where('id', $membershipId)->update([
                    'role' => $invitation->role, 'active' => true, 'updated_at' => now(),
                ]);
            }
            DB::table('organization_invitations')->where('id', $invitation->id)
                ->update(['accepted_at' => now(), 'updated_at' => now()]);
            DB::table('audit_events')->insert([
                'id' => (string) Str::uuid(), 'organization_id' => $organization->id,
                'actor_user_id' => $user->id, 'action' => 'membership.created',
                'subject_type' => 'organization_membership', 'subject_id' => $membershipId,
                'ip_address' => $request->ip(), 'created_at' => now(),
            ]);

            return $user;
        });

        if ($user === null) {
            return response()->json(['message' => 'Invalid invitation or credentials.'], 401);
        }

        return response()->json(['user' => $user->only(['id', 'name', 'email'])], 201);
    }
}
