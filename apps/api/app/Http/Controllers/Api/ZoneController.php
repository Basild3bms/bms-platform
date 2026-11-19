<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Building;
use App\Models\Floor;
use App\Models\Organization;
use App\Models\Zone;
use Illuminate\Database\QueryException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class ZoneController extends Controller
{
    public function index(Request $request, Organization $organization, string $building, string $floor): JsonResponse
    {
        Gate::authorize('viewZones', $organization);
        $parent = $this->findFloor($organization, $building, $floor);
        $filters = $request->validate([
            'page' => ['sometimes', 'integer', 'min:1'],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:100'],
        ]);
        $zones = Zone::query()->where('organization_id', $organization->id)
            ->where('building_id', $parent->building_id)->where('floor_id', $parent->id)
            ->orderBy('code')->orderBy('id')->paginate($filters['per_page'] ?? 25);

        return response()->json([
            'data' => array_map($this->resource(...), $zones->items()),
            'meta' => ['current_page' => $zones->currentPage(), 'per_page' => $zones->perPage(),
                'total' => $zones->total(), 'last_page' => $zones->lastPage()],
        ]);
    }

    public function store(Request $request, Organization $organization, string $building, string $floor): JsonResponse
    {
        Gate::authorize('manageZones', $organization);
        $parent = $this->findFloor($organization, $building, $floor);
        $data = $request->validate($this->rules($parent));

        try {
            $zone = DB::transaction(function () use ($request, $organization, $parent, $data): Zone {
                $zone = new Zone;
                $zone->id = (string) Str::uuid();
                $zone->organization_id = $organization->id;
                $zone->building_id = $parent->building_id;
                $zone->floor_id = $parent->id;
                $zone->fill($data);
                $zone->save();
                $this->audit($request, $organization, 'zone.created', $zone->id);

                return $zone;
            });
        } catch (QueryException $exception) {
            $this->rethrowCodeConflict($exception);
        }

        return response()->json(['data' => $this->resource($zone)], 201);
    }

    public function show(Request $request, Organization $organization, string $building, string $floor, string $zone): JsonResponse
    {
        Gate::authorize('viewZones', $organization);
        $parent = $this->findFloor($organization, $building, $floor);
        $record = $this->findZone($organization, $parent, $zone);

        return response()->json(['data' => $this->resource($record)]);
    }

    public function update(Request $request, Organization $organization, string $building, string $floor, string $zone): JsonResponse
    {
        Gate::authorize('manageZones', $organization);
        $parent = $this->findFloor($organization, $building, $floor);
        $record = $this->findZone($organization, $parent, $zone);
        $data = $request->validate($this->rules($parent, $record));
        if ($data === []) {
            throw ValidationException::withMessages(['zone' => 'At least one field is required.']);
        }

        try {
            DB::transaction(function () use ($request, $organization, $record, $data): void {
                $record->fill($data);
                $record->save();
                $this->audit($request, $organization, 'zone.updated', $record->id);
            });
        } catch (QueryException $exception) {
            $this->rethrowCodeConflict($exception);
        }

        return response()->json(['data' => $this->resource($record)]);
    }

    private function findFloor(Organization $organization, string $building, string $floor): Floor
    {
        $parent = Building::query()->where('organization_id', $organization->id)
            ->whereKey($building)->firstOrFail();

        return Floor::query()->where('organization_id', $organization->id)
            ->where('building_id', $parent->id)->whereKey($floor)->firstOrFail();
    }

    private function findZone(Organization $organization, Floor $floor, string $zone): Zone
    {
        return Zone::query()->where('organization_id', $organization->id)
            ->where('building_id', $floor->building_id)->where('floor_id', $floor->id)
            ->whereKey($zone)->firstOrFail();
    }

    private function rules(Floor $floor, ?Zone $zone = null): array
    {
        $presence = $zone === null ? 'required' : 'sometimes';
        $uniqueCode = Rule::unique('zones', 'code')->where('floor_id', $floor->id);
        if ($zone !== null) {
            $uniqueCode->ignore($zone->id);
        }

        return [
            'name' => [$presence, 'required', 'string', 'max:255'],
            'code' => [$presence, 'required', 'string', 'max:64',
                'regex:/\A[A-Za-z0-9][A-Za-z0-9_-]*\z/', $uniqueCode],
            'zone_type' => [$presence, 'required', Rule::in(Zone::TYPES)],
            'organization_id' => ['missing'],
            'building_id' => ['missing'],
            'floor_id' => ['missing'],
        ];
    }

    private function resource(Zone $zone): array
    {
        return $zone->only(['id', 'organization_id', 'building_id', 'floor_id', 'name',
            'code', 'zone_type', 'created_at', 'updated_at']);
    }

    private function audit(Request $request, Organization $organization, string $action, string $zoneId): void
    {
        DB::table('audit_events')->insert(['id' => (string) Str::uuid(),
            'organization_id' => $organization->id, 'actor_user_id' => $request->user()->id,
            'action' => $action, 'subject_type' => 'zone', 'subject_id' => $zoneId,
            'ip_address' => $request->ip(), 'created_at' => now()]);
    }

    private function rethrowCodeConflict(QueryException $exception): never
    {
        $error = $exception->errorInfo;
        $isPostgresConflict = ($error[0] ?? null) === '23505'
            && str_contains($error[2] ?? '', 'constraint "zones_floor_id_code_unique"');
        $isSqliteConflict = (int) ($error[1] ?? 0) === 19
            && str_starts_with($error[2] ?? '', 'UNIQUE constraint failed: zones.floor_id, zones.code');
        if ($isPostgresConflict || $isSqliteConflict) {
            throw ValidationException::withMessages(['code' => 'The code has already been taken.']);
        }

        throw $exception;
    }
}
