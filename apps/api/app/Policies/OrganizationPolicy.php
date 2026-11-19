<?php

namespace App\Policies;

use App\Models\Organization;
use App\Models\User;
use Illuminate\Auth\Access\Response;
use Illuminate\Support\Facades\DB;

class OrganizationPolicy
{
    private function membership(User $user, Organization $organization): ?object
    {
        return DB::table('organization_memberships')->where('organization_id', $organization->id)
            ->where('user_id', $user->id)->where('active', true)->first();
    }

    public function viewMembers(User $user, Organization $organization): Response
    {
        return $this->permission($user, $organization, 'users.view');
    }

    public function manageMembers(User $user, Organization $organization): Response
    {
        return $this->permission($user, $organization, 'users.manage');
    }

    public function viewBuildings(User $user, Organization $organization): Response
    {
        return $this->permission($user, $organization, 'buildings.view');
    }

    public function manageBuildings(User $user, Organization $organization): Response
    {
        return $this->permission($user, $organization, 'buildings.manage');
    }

    public function viewFloors(User $user, Organization $organization): Response
    {
        return $this->permission($user, $organization, 'floors.view');
    }

    public function manageFloors(User $user, Organization $organization): Response
    {
        return $this->permission($user, $organization, 'floors.manage');
    }

    public function viewZones(User $user, Organization $organization): Response
    {
        return $this->permission($user, $organization, 'zones.view');
    }

    public function manageZones(User $user, Organization $organization): Response
    {
        return $this->permission($user, $organization, 'zones.manage');
    }

    public function assignRole(User $user, Organization $organization, string $role): Response
    {
        $membership = $this->membership($user, $organization);
        if ($membership === null) {
            return Response::denyAsNotFound();
        }
        $actorRank = DB::table('roles')->where('code', $membership->role)->value('rank');
        $targetRank = DB::table('roles')->where('code', $role)->value('rank');

        return $this->permission($user, $organization, 'users.manage')->allowed()
            && $targetRank !== null && $actorRank > $targetRank
            ? Response::allow() : Response::deny();
    }

    private function permission(User $user, Organization $organization, string $permission): Response
    {
        $membership = $this->membership($user, $organization);
        if ($membership === null) {
            return Response::denyAsNotFound();
        }

        return DB::table('role_permissions')->where('role_code', $membership->role)
            ->where('permission_code', $permission)->exists() ? Response::allow() : Response::deny();
    }
}
