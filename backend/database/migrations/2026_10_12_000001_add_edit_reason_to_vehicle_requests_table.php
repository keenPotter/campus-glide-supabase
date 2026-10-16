<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    // The reason a faculty member gives when editing a request that was already approved.
    public function up(): void
    {
        if (Schema::hasColumn('vehicle_requests', 'edit_reason')) {
            return;
        }

        Schema::table('vehicle_requests', function (Blueprint $table) {
            $table->string('edit_reason', 500)->nullable()->after('disapproval_reason');
        });
    }

    public function down(): void
    {
        Schema::table('vehicle_requests', function (Blueprint $table) {
            $table->dropColumn('edit_reason');
        });
    }
};