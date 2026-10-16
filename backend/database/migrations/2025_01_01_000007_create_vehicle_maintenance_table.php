<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * `next_due_date` is added later by 2026_09_10_000000_add_next_due_date_to_vehicle_maintenance.php
     */
    public function up(): void
    {
        Schema::create('vehicle_maintenance', function (Blueprint $table) {
            $table->id();
            $table->foreignId('vehicle_id')->constrained('vehicles')->cascadeOnDelete();
            $table->enum('maintenance_type', ['oil_change', 'repair', 'refueling', 'inspection', 'tire_service', 'other']);
            $table->string('description', 500)->nullable();
            $table->date('maintenance_date');
            $table->date('completion_date')->nullable();
            $table->decimal('cost', 10, 2)->nullable();
            $table->string('performed_by', 100)->nullable();
            $table->enum('status', ['scheduled', 'in_progress', 'completed', 'cancelled'])->default('scheduled');
            $table->string('notes', 500)->nullable();
            $table->timestamps();

            $table->index(['vehicle_id', 'maintenance_date'], 'idx_vehicle_date');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('vehicle_maintenance');
    }
};