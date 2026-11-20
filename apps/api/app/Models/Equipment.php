<?php

namespace App\Models;

use Database\Factories\EquipmentFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

#[Fillable(['code', 'name', 'description', 'type_code', 'manufacturer', 'model',
    'serial_number', 'lifecycle_status', 'installed_on', 'commissioned_on',
    'specifications', 'spec_schema_version'])]
class Equipment extends Model
{
    /** @use HasFactory<EquipmentFactory> */
    use HasFactory;

    public $incrementing = false;

    protected $keyType = 'string';

    protected function casts(): array
    {
        return [
            'specifications' => 'array',
            'spec_schema_version' => 'integer',
            'installed_on' => 'date:Y-m-d',
            'commissioned_on' => 'date:Y-m-d',
        ];
    }
}
