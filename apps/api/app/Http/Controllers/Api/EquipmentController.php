<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Building;
use App\Models\Equipment;
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

class EquipmentController extends Controller
{
    private const STATUSES = ['planned', 'installed', 'commissioned', 'active', 'out_of_service', 'retired'];

    private const SPEC_KEYS = [
        'air' => ['design_airflow_m3_h', 'rated_power_kw'],
        'thermal' => ['design_capacity_kw', 'rated_power_kw'],
        'hydronic' => ['design_flow_m3_h', 'rated_power_kw'],
        'metering' => [], 'instrumentation' => [],
        'controls_hardware' => ['rated_power_kw'], 'general' => [],
    ];

    public function index(Request $request, Organization $organization, string $building): JsonResponse
    {
        Gate::authorize('viewEquipment', $organization);
        $parent = $this->building($organization, $building);
        $filters = $request->validate([
            'page' => ['sometimes', 'integer', 'min:1'],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:100'],
            'type_code' => ['sometimes', Rule::exists('equipment_types', 'code')->where('active', true)],
            'lifecycle_status' => ['sometimes', Rule::in(self::STATUSES)],
            'floor_id' => ['sometimes', 'uuid', Rule::exists('floors', 'id')->where('organization_id', $organization->id)->where('building_id', $parent->id)],
            'zone_id' => ['sometimes', 'uuid', Rule::exists('zones', 'id')->where('organization_id', $organization->id)->where('building_id', $parent->id)],
            'q' => ['sometimes', 'string', 'min:1', 'max:100'],
        ]);
        if (isset($filters['floor_id'], $filters['zone_id']) && ! Zone::query()
            ->whereKey($filters['zone_id'])->where('floor_id', $filters['floor_id'])->exists()) {
            throw ValidationException::withMessages(['zone_id' => 'The zone does not belong to the selected floor.']);
        }
        $query = Equipment::query()->where('organization_id', $organization->id)->where('building_id', $parent->id);
        foreach (['type_code', 'lifecycle_status', 'floor_id', 'zone_id'] as $key) {
            if (isset($filters[$key])) {
                $query->where($key, $filters[$key]);
            }
        }
        if (isset($filters['q'])) {
            $escaped = str_replace(['!', '%', '_'], ['!!', '!%', '!_'], strtoupper($filters['q']));
            $query->where(function ($search) use ($escaped): void {
                $search->whereRaw("UPPER(code) LIKE ? ESCAPE '!'", ["%$escaped%"])
                    ->orWhereRaw("UPPER(name) LIKE ? ESCAPE '!'", ["%$escaped%"]);
            });
        }
        $page = $query->orderBy('code')->orderBy('id')->paginate($filters['per_page'] ?? 25);

        return response()->json(['data' => array_map($this->resource(...), $page->items()),
            'meta' => ['current_page' => $page->currentPage(), 'per_page' => $page->perPage(),
                'total' => $page->total(), 'last_page' => $page->lastPage()]]);
    }

    public function store(Request $request, Organization $organization, string $building): JsonResponse
    {
        Gate::authorize('manageEquipment', $organization);

        return $this->create($request, $organization, $this->building($organization, $building));
    }

    public function storeOnFloor(Request $request, Organization $organization, string $building, string $floor): JsonResponse
    {
        Gate::authorize('manageEquipment', $organization);
        $parent = $this->building($organization, $building);

        return $this->create($request, $organization, $parent, $this->floor($organization, $parent, $floor));
    }

    public function storeInZone(Request $request, Organization $organization, string $building, string $floor, string $zone): JsonResponse
    {
        Gate::authorize('manageEquipment', $organization);
        $parent = $this->building($organization, $building);
        $locationFloor = $this->floor($organization, $parent, $floor);

        return $this->create($request, $organization, $parent, $locationFloor,
            $this->zone($organization, $locationFloor, $zone));
    }

    public function show(Request $request, Organization $organization, string $building, string $equipment): JsonResponse
    {
        Gate::authorize('viewEquipment', $organization);
        $parent = $this->building($organization, $building);

        return response()->json(['data' => $this->resource($this->equipment($organization, $parent, $equipment))]);
    }

    public function update(Request $request, Organization $organization, string $building, string $equipment): JsonResponse
    {
        Gate::authorize('manageEquipment', $organization);
        $parent = $this->building($organization, $building);
        $record = $this->equipment($organization, $parent, $equipment);
        $data = $this->validatedData($request, $parent, $record);
        if ($data === []) {
            throw ValidationException::withMessages(['equipment' => 'At least one field is required.']);
        }
        try {
            DB::transaction(function () use ($request, $organization, $record, $data): void {
                $record->fill($data);
                $record->save();
                $this->audit($request, $organization, 'equipment.updated', $record->id);
            });
        } catch (QueryException $exception) {
            $this->rethrowCodeConflict($exception);
        }

        return response()->json(['data' => $this->resource($record)]);
    }

    private function create(Request $request, Organization $organization, Building $building,
        ?Floor $floor = null, ?Zone $zone = null): JsonResponse
    {
        $data = $this->validatedData($request, $building);
        try {
            $record = DB::transaction(function () use ($request, $organization, $building, $floor, $zone, $data): Equipment {
                $record = new Equipment;
                $record->id = (string) Str::uuid();
                $record->organization_id = $organization->id;
                $record->building_id = $building->id;
                $record->floor_id = $floor?->id;
                $record->zone_id = $zone?->id;
                $record->fill($data);
                $record->save();
                $this->audit($request, $organization, 'equipment.created', $record->id);

                return $record;
            });
        } catch (QueryException $exception) {
            $this->rethrowCodeConflict($exception);
        }

        return response()->json(['data' => $this->resource($record)], 201);
    }

    private function validatedData(Request $request, Building $building, ?Equipment $record = null): array
    {
        $allowed = ['code', 'name', 'description', 'type_code', 'manufacturer', 'model', 'serial_number',
            'lifecycle_status', 'installed_on', 'commissioned_on', 'specifications', 'spec_schema_version'];
        $forbidden = ['id', 'organization_id', 'building_id', 'floor_id', 'zone_id', 'created_at',
            'updated_at', 'protocol', 'device_id', 'point_id', 'writable'];
        $unknown = array_diff(array_keys($request->all()), [...$allowed, ...$forbidden]);
        if ($unknown !== []) {
            throw ValidationException::withMessages([array_values($unknown)[0] => 'This field is not supported.']);
        }
        if (is_string($request->input('code'))) {
            $request->merge(['code' => strtoupper(trim($request->input('code')))]);
        }
        $presence = $record === null ? 'required' : 'sometimes';
        $uniqueCode = Rule::unique('equipment', 'code')->where('building_id', $building->id);
        if ($record !== null) {
            $uniqueCode->ignore($record->id);
        }
        $data = $request->validate([
            'code' => [$presence, 'required', 'string', 'max:64', 'regex:/\A[A-Z0-9][A-Z0-9_-]*\z/', $uniqueCode],
            'name' => [$presence, 'required', 'string', 'max:255'],
            'description' => ['sometimes', 'nullable', 'string', 'max:5000'],
            'type_code' => [$presence, 'required', Rule::exists('equipment_types', 'code')->where('active', true)],
            'manufacturer' => ['sometimes', 'nullable', 'string', 'max:255'],
            'model' => ['sometimes', 'nullable', 'string', 'max:255'],
            'serial_number' => ['sometimes', 'nullable', 'string', 'max:255'],
            'lifecycle_status' => ['sometimes', Rule::in(self::STATUSES)],
            'installed_on' => ['sometimes', 'nullable', 'date_format:Y-m-d'],
            'commissioned_on' => ['sometimes', 'nullable', 'date_format:Y-m-d'],
            'specifications' => ['sometimes', 'nullable', 'array'],
            'spec_schema_version' => ['sometimes', 'nullable', 'integer', Rule::in([1])],
            ...array_fill_keys($forbidden, ['missing']),
        ]);
        $type = $data['type_code'] ?? $record?->type_code;
        $description = array_key_exists('description', $data) ? $data['description'] : $record?->description;
        if ($type === 'other' && trim((string) $description) === '') {
            throw ValidationException::withMessages(['description' => 'A description is required for other equipment.']);
        }
        $installed = array_key_exists('installed_on', $data) ? $data['installed_on'] : $record?->installed_on?->format('Y-m-d');
        $commissioned = array_key_exists('commissioned_on', $data) ? $data['commissioned_on'] : $record?->commissioned_on?->format('Y-m-d');
        if ($installed !== null && $commissioned !== null && $commissioned < $installed) {
            throw ValidationException::withMessages(['commissioned_on' => 'Commissioning cannot precede installation.']);
        }
        $this->validateSpecifications($request, $data, $record, $type);

        return $data;
    }

    private function validateSpecifications(Request $request, array &$data, ?Equipment $record, string $type): void
    {
        if (! array_key_exists('specifications', $data) && ! array_key_exists('spec_schema_version', $data)
            && ($record === null || $record->type_code === $type)) {
            return;
        }
        if (array_key_exists('spec_schema_version', $data) && ! array_key_exists('specifications', $data)) {
            throw ValidationException::withMessages(['specifications' => 'Specifications must accompany a schema version.']);
        }
        $specifications = array_key_exists('specifications', $data) ? $data['specifications'] : $record?->specifications;
        if ($specifications === null) {
            if (isset($data['spec_schema_version'])) {
                throw ValidationException::withMessages(['spec_schema_version' => 'A version requires specifications.']);
            }
            $data['spec_schema_version'] = null;

            return;
        }
        if (($data['spec_schema_version'] ?? $record?->spec_schema_version) !== 1) {
            throw ValidationException::withMessages(['spec_schema_version' => 'Specification schema version 1 is required.']);
        }
        if (array_key_exists('specifications', $data) && $request->isJson()) {
            $body = json_decode($request->getContent());
            if (! is_object($body?->specifications ?? null)) {
                throw ValidationException::withMessages(['specifications' => 'Specifications must be a JSON object.']);
            }
        }
        $encoded = json_encode($specifications);
        if ($encoded === false || strlen($encoded) > 4096) {
            throw ValidationException::withMessages(['specifications' => 'Specifications exceed the supported size.']);
        }
        $family = DB::table('equipment_types')->where('code', $type)->value('family');
        $allowed = self::SPEC_KEYS[$family] ?? [];
        foreach ($specifications as $key => $value) {
            if (! in_array($key, $allowed, true) || ! is_numeric($value) || is_string($value)
                || ! is_finite((float) $value) || $value > 1000000000
                || ($key === 'rated_power_kw' ? $value < 0 : $value <= 0)) {
                throw ValidationException::withMessages(['specifications' => "Invalid engineering value for $key."]);
            }
        }
        if ($specifications === []) {
            $data['specifications'] = (object) [];
        }
        $data['spec_schema_version'] = 1;
    }

    private function building(Organization $organization, string $building): Building
    {
        return Building::query()->where('organization_id', $organization->id)->whereKey($building)->firstOrFail();
    }

    private function floor(Organization $organization, Building $building, string $floor): Floor
    {
        return Floor::query()->where('organization_id', $organization->id)
            ->where('building_id', $building->id)->whereKey($floor)->firstOrFail();
    }

    private function zone(Organization $organization, Floor $floor, string $zone): Zone
    {
        return Zone::query()->where('organization_id', $organization->id)
            ->where('building_id', $floor->building_id)->where('floor_id', $floor->id)->whereKey($zone)->firstOrFail();
    }

    private function equipment(Organization $organization, Building $building, string $equipment): Equipment
    {
        return Equipment::query()->where('organization_id', $organization->id)
            ->where('building_id', $building->id)->whereKey($equipment)->firstOrFail();
    }

    private function resource(Equipment $record): array
    {
        return [...$record->only(['id', 'organization_id', 'building_id', 'floor_id', 'zone_id',
            'code', 'name', 'description', 'type_code', 'manufacturer', 'model', 'serial_number',
            'lifecycle_status', 'spec_schema_version', 'created_at', 'updated_at']),
            'specifications' => $record->specifications === [] ? (object) [] : $record->specifications,
            'installed_on' => $record->installed_on?->format('Y-m-d'),
            'commissioned_on' => $record->commissioned_on?->format('Y-m-d')];
    }

    private function audit(Request $request, Organization $organization, string $action, string $equipmentId): void
    {
        DB::table('audit_events')->insert(['id' => (string) Str::uuid(),
            'organization_id' => $organization->id, 'actor_user_id' => $request->user()->id,
            'action' => $action, 'subject_type' => 'equipment', 'subject_id' => $equipmentId,
            'ip_address' => $request->ip(), 'created_at' => now()]);
    }

    private function rethrowCodeConflict(QueryException $exception): never
    {
        $error = $exception->errorInfo;
        $postgres = ($error[0] ?? null) === '23505'
            && str_contains($error[2] ?? '', 'equipment_building_code_unique');
        $sqlite = (int) ($error[1] ?? 0) === 19
            && str_contains($error[2] ?? '', 'UNIQUE constraint failed: equipment.building_id, equipment.code');
        if ($postgres || $sqlite) {
            throw ValidationException::withMessages(['code' => 'The code has already been taken.']);
        }

        throw $exception;
    }
}
