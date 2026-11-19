<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Building;
use App\Models\Organization;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class BuildingController extends Controller
{
    public function index(Request $request, Organization $organization): JsonResponse
    {
        Gate::authorize('viewBuildings', $organization);
        $filters = $request->validate([
            'page' => ['sometimes', 'integer', 'min:1'],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:100'],
        ]);
        $buildings = Building::query()->where('organization_id', $organization->id)
            ->orderBy('code')->orderBy('id')
            ->paginate($filters['per_page'] ?? 25);

        return response()->json([
            'data' => array_map($this->resource(...), $buildings->items()),
            'meta' => [
                'current_page' => $buildings->currentPage(),
                'per_page' => $buildings->perPage(),
                'total' => $buildings->total(),
                'last_page' => $buildings->lastPage(),
            ],
        ]);
    }

    public function store(Request $request, Organization $organization): JsonResponse
    {
        Gate::authorize('manageBuildings', $organization);
        $data = $request->validate($this->rules($organization));

        $building = DB::transaction(function () use ($request, $organization, $data): Building {
            $building = new Building;
            $building->id = (string) Str::uuid();
            $building->organization_id = $organization->id;
            $building->fill($data);
            $building->save();
            $this->audit($request, $organization, 'building.created', $building->id);

            return $building;
        });

        return response()->json(['data' => $this->resource($building)], 201);
    }

    public function show(Request $request, Organization $organization, string $building): JsonResponse
    {
        Gate::authorize('viewBuildings', $organization);
        $record = $this->findBuilding($organization, $building);

        return response()->json(['data' => $this->resource($record)]);
    }

    public function update(Request $request, Organization $organization, string $building): JsonResponse
    {
        Gate::authorize('manageBuildings', $organization);
        $record = $this->findBuilding($organization, $building);
        $data = $request->validate($this->rules($organization, $record));
        if ($data === []) {
            throw ValidationException::withMessages(['building' => 'At least one field is required.']);
        }

        DB::transaction(function () use ($request, $organization, $record, $data): void {
            $record->fill($data);
            $record->save();
            $this->audit($request, $organization, 'building.updated', $record->id);
        });

        return response()->json(['data' => $this->resource($record)]);
    }

    private function findBuilding(Organization $organization, string $building): Building
    {
        return Building::query()->where('organization_id', $organization->id)
            ->whereKey($building)->firstOrFail();
    }

    private function rules(Organization $organization, ?Building $building = null): array
    {
        $presence = $building === null ? 'required' : 'sometimes';
        $uniqueCode = Rule::unique('buildings', 'code')
            ->where('organization_id', $organization->id);
        if ($building !== null) {
            $uniqueCode->ignore($building->id);
        }

        return [
            'name' => [$presence, 'required', 'string', 'max:255'],
            'code' => [$presence, 'required', 'string', 'max:64', 'regex:/\A[A-Za-z0-9][A-Za-z0-9_-]*\z/', $uniqueCode],
            'address' => ['sometimes', 'nullable', 'string', 'max:255'],
            'timezone' => [$presence, 'required', 'timezone'],
            'organization_id' => ['prohibited'],
        ];
    }

    private function resource(Building $building): array
    {
        return $building->only([
            'id', 'organization_id', 'name', 'code', 'address', 'timezone',
            'created_at', 'updated_at',
        ]);
    }

    private function audit(Request $request, Organization $organization, string $action, string $buildingId): void
    {
        DB::table('audit_events')->insert([
            'id' => (string) Str::uuid(),
            'organization_id' => $organization->id,
            'actor_user_id' => $request->user()->id,
            'action' => $action,
            'subject_type' => 'building',
            'subject_id' => $buildingId,
            'ip_address' => $request->ip(),
            'created_at' => now(),
        ]);
    }
}
