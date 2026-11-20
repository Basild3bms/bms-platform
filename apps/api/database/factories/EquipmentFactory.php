<?php

namespace Database\Factories;

use App\Models\Equipment;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Equipment>
 */
class EquipmentFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'id' => (string) fake()->uuid(),
            'code' => strtoupper(fake()->unique()->bothify('EQ-####')),
            'name' => fake()->words(3, true),
            'type_code' => 'ahu',
            'lifecycle_status' => 'planned',
        ];
    }

    public function forBuilding(string $organizationId, string $buildingId): static
    {
        return $this->state(fn (): array => [
            'organization_id' => $organizationId,
            'building_id' => $buildingId,
        ]);
    }
}
