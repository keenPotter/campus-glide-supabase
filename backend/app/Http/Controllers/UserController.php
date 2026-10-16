<?php

namespace App\Http\Controllers;

use App\Http\Resources\UserResource;
use App\Models\User;

class UserController extends Controller
{
    /**
     * GET /api/users
     * Administrators only (route middleware).
     */
    public function index()
    {
        return UserResource::collection(
            User::orderBy('last_name')->orderBy('first_name')->get()
        );
    }
}