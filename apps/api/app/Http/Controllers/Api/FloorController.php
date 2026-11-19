<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Building;
use App\Models\Floor;
use App\Models\Organization;
use Illuminate\Database\QueryException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class FloorController extends Controller
{
    public function index(Request $request, Organization $organization, string $building): JsonResponse
    {
        Gate::authorize('viewFloors', $organization);
        $parent = $this->findBuilding($organization, $building);
        $filters = $request->validate([
            'page' => ['sometimes', 'integer', 'min:1'],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:100'],
        ]);
        $floors = Floor::query()->where('organization_id', $organization->id)
            ->where('building_id', $parent->id)->orderBy('code')->orderBy('id')
            ->paginate($filters['per_page'] ?? 25);

        return response()->json([
            'data' => array_map($this->resource(...), $floors->items()),
            'meta' => ['current_page' => $floors->currentPage(), 'per_page' => $floors->perPage(),
                'total' => $floors->total(), 'last_page' => $floors->lastPage()],
        ]);
    }

    public function store(Request $request, Organization $organization, string $building): JsonResponse
    {
        Gate::authorize('manageFloors', $organization);
        $parent = $this->findBuilding($organization, $building);
        $data = $request->validate($this->rules($parent));

        try {
            $floor = DB::transaction(function () use ($request, $organization, $parent, $data): Floor {
                $floor = new Floor;
                $floor->id = (string) Str::uuid();
                $floor->organization_id = $organization->id;
                $floor->building_id = $parent->id;
                $floor->fill($data);
                $floor->save();
                $this->audit($request, $organization, 'floor.created', $floor->id);

                return $floor;
            });
        } catch (QueryException $exception) {
            $this->rethrowCodeConflict($exception);
        }

        return response()->json(['data' => $this->resource($floor)], 201);
    }

    public function show(Request $request, Organization $organization, string $building, string $floor): JsonResponse
    {
        Gate::authorize('viewFloors', $organization);
        $parent = $this->findBuilding($organization, $building);
        $record = $this->findFloor($organization, $parent, $floor);

        return response()->json(['data' => $this->resource($record)]);
    }

    public function update(Request $request, Organization $organization, string $building, string $floor): JsonResponse
    {
        Gate::authorize('manageFloors', $organization);
        $parent = $this->findBuilding($organization, $building);
        $record = $this->findFloor($organization, $parent, $floor);
        $data = $request->validate($this->rules($parent, $record));
        if ($data === []) {
            throw ValidationException::withMessages(['floor' => 'At least one field is required.']);
        }

        try {
            DB::transaction(function () use ($request, $organization, $record, $data): void {
                $record->fill($data);
                $record->save();
                $this->audit($request, $organization, 'floor.updated', $record->id);
            });
        } catch (QueryException $exception) {
            $this->rethrowCodeConflict($exception);
        }

        return response()->json(['data' => $this->resource($record)]);
    }

    private function findBuilding(Organization $organization, string $building): Building
    {
        return Building::query()->where('organization_id', $organization->id)
            ->whereKey($building)->firstOrFail();
    }

    private function findFloor(Organization $organization, Building $building, string $floor): Floor
    {
        return Floor::query()->where('organization_id', $organization->id)
            ->where('building_id', $building->id)->whereKey($floor)->firstOrFail();
    }

    private function rules(Building $building, ?Floor $floor = null): array
    {
        $presence = $floor === null ? 'required' : 'sometimes';
        $uniqueCode = Rule::unique('floors', 'code')->where('building_id', $building->id);
        if ($floor !== null) {
            $uniqueCode->ignore($floor->id);
        }

        return [
            'name' => [$presence, 'required', 'string', 'max:255'],
            'code' => [$presence, 'required', 'string', 'max:64',
                'regex:/\A[A-Za-z0-9][A-Za-z0-9_-]*\z/', $uniqueCode],
            'level' => [$presence, 'required', 'integer', 'min:-2147483648', 'max:2147483647'],
            'organization_id' => ['missing'],
            'building_id' => ['missing'],
        ];
    }

    private function resource(Floor $floor): array
    {
        return $floor->only(['id', 'organization_id', 'building_id', 'name', 'code',
            'level', 'created_at', 'updated_at']);
    }

    private function audit(Request $request, Organization $organization, string $action, string $floorId): void
    {
        DB::table('audit_events')->insert(['id' => (string) Str::uuid(),
            'organization_id' => $organization->id, 'actor_user_id' => $request->user()->id,
            'action' => $action, 'subject_type' => 'floor', 'subject_id' => $floorId,
            'ip_address' => $request->ip(), 'created_at' => now()]);
    }

    private function rethrowCodeConflict(QueryException $exception): never
    {
        $error = $exception->errorInfo;
        $isPostgresConflict = ($error[0] ?? null) === '23505'
            && str_contains($error[2] ?? '', 'constraint "floors_building_id_code_unique"');
        $isSqliteConflict = (int) ($error[1] ?? 0) === 19
            && str_starts_with($error[2] ?? '', 'UNIQUE constraint failed: floors.building_id, floors.code');
        if ($isPostgresConflict || $isSqliteConflict) {
            throw ValidationException::withMessages(['code' => 'The code has already been taken.']);
        }

        throw $exception;
    }
}
