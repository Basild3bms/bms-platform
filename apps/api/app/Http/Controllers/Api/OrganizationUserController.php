<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Organization;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class OrganizationUserController extends Controller
{
    public function index(Organization $organization): JsonResponse
    {
        Gate::authorize('viewMembers', $organization);
        $members = DB::table('organization_memberships as m')
            ->join('users as u', 'u.id', '=', 'm.user_id')
            ->where('m.organization_id', $organization->id)->where('m.active', true)
            ->select('m.id', 'm.role', 'u.id as user_id', 'u.name', 'u.email')
            ->orderBy('u.name')->limit(100)->get();

        return response()->json(['data' => $members]);
    }

    public function store(Request $request, Organization $organization): JsonResponse
    {
        Gate::authorize('manageMembers', $organization);
        if (is_string($request->input('email'))) {
            $request->merge(['email' => Str::lower(trim($request->input('email')))]);
        }
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', Rule::unique('users', 'email')],
            'password' => ['required', 'string', 'min:12', 'max:128'],
            'role' => ['required', Rule::exists('roles', 'code')],
        ]);
        Gate::authorize('assignRole', [$organization, $data['role']]);

        $user = DB::transaction(function () use ($request, $organization, $data): User {
            $user = User::create([
                'name' => $data['name'], 'email' => Str::lower(trim($data['email'])),
                'password' => $data['password'],
            ]);
            $membershipId = (string) Str::uuid();
            DB::table('organization_memberships')->insert([
                'id' => $membershipId, 'organization_id' => $organization->id,
                'user_id' => $user->id, 'role' => $data['role'], 'active' => true,
                'created_at' => now(), 'updated_at' => now(),
            ]);
            $this->audit($request, $organization, 'membership.created', $membershipId);

            return $user;
        });

        return response()->json(['user' => $user->only(['id', 'name', 'email']), 'role' => $data['role']], 201);
    }

    public function update(Request $request, Organization $organization, string $membership): JsonResponse
    {
        Gate::authorize('manageMembers', $organization);
        $target = DB::table('organization_memberships')->where('id', $membership)
            ->where('organization_id', $organization->id)->where('active', true)->first();
        abort_if($target === null, 404);
        Gate::authorize('assignRole', [$organization, $target->role]);
        $data = $request->validate(['role' => ['required', Rule::exists('roles', 'code')]]);
        Gate::authorize('assignRole', [$organization, $data['role']]);
        DB::transaction(function () use ($request, $organization, $membership, $data): void {
            DB::table('organization_memberships')->where('id', $membership)->update([
                'role' => $data['role'], 'updated_at' => now(),
            ]);
            $this->audit($request, $organization, 'membership.role_updated', $membership);
        });

        return response()->json(['id' => $membership, 'role' => $data['role']]);
    }

    public function destroy(Request $request, Organization $organization, string $membership): JsonResponse
    {
        Gate::authorize('manageMembers', $organization);
        $target = DB::table('organization_memberships')->where('id', $membership)
            ->where('organization_id', $organization->id)->where('active', true)->first();
        abort_if($target === null, 404);
        Gate::authorize('assignRole', [$organization, $target->role]);
        DB::transaction(function () use ($request, $organization, $membership): void {
            DB::table('organization_memberships')->where('id', $membership)->update([
                'active' => false, 'updated_at' => now(),
            ]);
            $this->audit($request, $organization, 'membership.revoked', $membership);
        });

        return response()->json(['message' => 'Membership revoked.']);
    }

    private function audit(Request $request, Organization $organization, string $action, string $membership): void
    {
        DB::table('audit_events')->insert([
            'id' => (string) Str::uuid(), 'organization_id' => $organization->id,
            'actor_user_id' => $request->user()->id, 'action' => $action,
            'subject_type' => 'organization_membership', 'subject_id' => $membership,
            'ip_address' => $request->ip(), 'created_at' => now(),
        ]);
    }
}
