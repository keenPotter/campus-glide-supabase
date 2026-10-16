<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    // Lets an administrator disapprove a date change request and keep it on record with the reason.
    // 'cancelled' stays for old data.
    public function up(): void
    {
        Schema::table('reschedule_requests', function (Blueprint $table) {
            $table->enum('status', ['pending', 'approved', 'disapproved', 'cancelled'])
                ->default('pending')
                ->change();
        });
    }

    public function down(): void
    {
        DB::table('reschedule_requests')->where('status', 'disapproved')->update(['status' => 'cancelled']);

        Schema::table('reschedule_requests', function (Blueprint $table) {
            $table->enum('status', ['pending', 'approved', 'cancelled'])
                ->default('pending')
                ->change();
        });
    }
};