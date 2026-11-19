<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\BuildingController;
use App\Http\Controllers\Api\FloorController;
use App\Http\Controllers\Api\InvitationController;
use App\Http\Controllers\Api\OrganizationUserController;
use App\Http\Controllers\Api\ZoneController;
use App\Http\Middleware\RequireActiveBearerToken;
use Illuminate\Support\Facades\Route;

Route::get('/v1/status', fn () => response()->json([
    'service' => 'bms-api',
    'version' => '0.1.0',
    'status' => 'ok',
]));

Route::post('/v1/auth/login', [AuthController::class, 'login']);
Route::post('/v1/invitations/accept', [InvitationController::class, 'accept'])->middleware('throttle:5,1');
Route::middleware(['auth:sanctum', RequireActiveBearerToken::class])->prefix('v1')->group(function (): void {
    Route::get('/auth/me', [AuthController::class, 'me']);
    Route::get('/auth/organizations', [AuthController::class, 'organizations']);
    Route::post('/auth/logout', [AuthController::class, 'logout']);
    Route::get('/organizations/{organization}/buildings', [BuildingController::class, 'index']);
    Route::post('/organizations/{organization}/buildings', [BuildingController::class, 'store']);
    Route::get('/organizations/{organization}/buildings/{building}', [BuildingController::class, 'show']);
    Route::patch('/organizations/{organization}/buildings/{building}', [BuildingController::class, 'update']);
    Route::get('/organizations/{organization}/buildings/{building}/floors', [FloorController::class, 'index'])->whereUuid(['organization', 'building']);
    Route::post('/organizations/{organization}/buildings/{building}/floors', [FloorController::class, 'store'])->whereUuid(['organization', 'building']);
    Route::get('/organizations/{organization}/buildings/{building}/floors/{floor}', [FloorController::class, 'show'])->whereUuid(['organization', 'building', 'floor']);
    Route::patch('/organizations/{organization}/buildings/{building}/floors/{floor}', [FloorController::class, 'update'])->whereUuid(['organization', 'building', 'floor']);
    Route::get('/organizations/{organization}/buildings/{building}/floors/{floor}/zones', [ZoneController::class, 'index'])->whereUuid(['organization', 'building', 'floor']);
    Route::post('/organizations/{organization}/buildings/{building}/floors/{floor}/zones', [ZoneController::class, 'store'])->whereUuid(['organization', 'building', 'floor']);
    Route::get('/organizations/{organization}/buildings/{building}/floors/{floor}/zones/{zone}', [ZoneController::class, 'show'])->whereUuid(['organization', 'building', 'floor', 'zone']);
    Route::patch('/organizations/{organization}/buildings/{building}/floors/{floor}/zones/{zone}', [ZoneController::class, 'update'])->whereUuid(['organization', 'building', 'floor', 'zone']);
    Route::get('/organizations/{organization}/users', [OrganizationUserController::class, 'index']);
    Route::post('/organizations/{organization}/users', [OrganizationUserController::class, 'store']);
    Route::patch('/organizations/{organization}/memberships/{membership}', [OrganizationUserController::class, 'update']);
    Route::delete('/organizations/{organization}/memberships/{membership}', [OrganizationUserController::class, 'destroy']);
});
