<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

#[Fillable(['name', 'code', 'zone_type'])]
class Zone extends Model
{
    public const TYPES = ['office', 'plant_room', 'common', 'retail', 'storage', 'other'];

    public $incrementing = false;

    protected $keyType = 'string';
}
