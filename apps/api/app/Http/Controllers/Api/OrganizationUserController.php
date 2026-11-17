<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Organization;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class OrganizationUserController extends Controller
{
    public function index(Request $request, Organization $organization): JsonResponse
    {
        Gate::authorize('viewMembers', $organization);
        $filters = $request->validate([
            'page' => ['sometimes', 'integer', 'min:1'],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:100'],
            'search' => ['sometimes', 'string', 'max:255'],
            'role' => ['sometimes', Rule::exists('roles', 'code')],
        ]);
        $members = DB::table('organization_memberships as m')
            ->join('users as u', 'u.id', '=', 'm.user_id')
            ->where('m.organization_id', $organization->id)->where('m.active', true)
            ->select('m.id', 'm.role', 'u.id as user_id', 'u.name', 'u.email')
            ->when(isset($filters['role']), fn ($query) => $query->where('m.role', $filters['role']))
            ->when(isset($filters['search']), function ($query) use ($filters): void {
                $search = '%'.str_replace(['!', '%', '_'], ['!!', '!%', '!_'], $filters['search']).'%';
                $query->where(function ($query) use ($search): void {
                    $query->whereRaw("u.name LIKE ? ESCAPE '!'", [$search])
                        ->orWhereRaw("u.email LIKE ? ESCAPE '!'", [$search]);
                });
            })
            ->orderBy('u.name')->orderBy('m.id')
            ->paginate($filters['per_page'] ?? 25);

        return response()->json([
            'data' => $members->items(),
            'meta' => ['current_page' => $members->currentPage(), 'per_page' => $members->perPage(),
                'total' => $members->total(), 'last_page' => $members->lastPage()],
        ]);
    }

    public function store(Request $request, Organization $organization): JsonResponse
    {
        Gate::authorize('manageMembers', $organization);
        if (is_string($request->input('email'))) {
            $request->merge(['email' => Str::lower(trim($request->input('email')))]);
        }
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255'],
            'password' => ['prohibited'],
            'role' => ['required', Rule::exists('roles', 'code')],
        ]);
        Gate::authorize('assignRole', [$organization, $data['role']]);

        $token = Str::random(64);
        DB::transaction(function () use ($request, $organization, $data, $token): void {
            $invitationId = (string) Str::uuid();
            DB::table('organization_invitations')->insert([
                'id' => $invitationId, 'organization_id' => $organization->id,
                'invited_by_user_id' => $request->user()->id,
                'name' => $data['name'], 'email' => $data['email'], 'role' => $data['role'],
                'token_hash' => hash('sha256', $token), 'expires_at' => now()->addDay(),
                'created_at' => now(), 'updated_at' => now(),
            ]);
            $this->audit($request, $organization, 'membership.invited', $invitationId);
        });

        return response()->json(['message' => 'Invitation created.', 'invitation_token' => $token], 202);
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
