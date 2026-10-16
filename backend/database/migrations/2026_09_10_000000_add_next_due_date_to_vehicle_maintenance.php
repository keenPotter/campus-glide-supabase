<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * Adds `next_due_date` to the existing `vehicle_maintenance` table
     * for the Sprint 3 Maintenance Monitoring API. No existing columns
     * are renamed or removed — `maintenance_type`, `maintenance_date`,
     * `completion_date`, `status`, `performed_by`, and `notes` all stay
     * exactly as they are.
     */
    public function up(): void
    {
        Schema::table('vehicle_maintenance', function (Blueprint $table) {
            $table->date('next_due_date')->nullable()->after('cost');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('vehicle_maintenance', function (Blueprint $table) {
            $table->dropColumn('next_due_date');
        });
    }
};
