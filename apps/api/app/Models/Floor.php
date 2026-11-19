<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

#[Fillable(['name', 'code', 'level'])]
class Floor extends Model
{
    public $incrementing = false;

    protected $keyType = 'string';
}
