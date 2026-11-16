<?php

use Illuminate\Support\Facades\Route;

Route::get('/v1/status', fn () => response()->json([
    'service' => 'bms-api',
    'version' => '0.1.0',
    'status' => 'ok',
]));
