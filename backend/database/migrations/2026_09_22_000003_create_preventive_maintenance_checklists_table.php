<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('preventive_maintenance_checklists', function (Blueprint $table) {
            $table->id();
            $table->foreignId('vehicle_id')->constrained('vehicles')->restrictOnDelete();
            $table->string('pmuv_no', 100)->nullable();
            $table->date('inspection_date');
            $table->string('inspector_mechanic', 255)->nullable();
            $table->unsignedInteger('current_mileage')->nullable();

            $table->date('last_oil_change')->nullable();
            $table->date('last_air_filter_change')->nullable();
            $table->date('last_cabin_filter_change')->nullable();
            $table->date('last_oil_filter_change')->nullable();
            $table->date('last_engine_tune_up')->nullable();

            $ratings = [
                'belts_condition', 'hoses_condition', 'engine_condition',
                'air_conditioning_condition', 'wipers_condition',
                'headlights_condition', 'driving_lights_condition',
                'brake_lights_condition', 'hazard_lights_condition',
                'door_locks_condition', 'windows_windshield_condition',
                'radio_condition', 'tires_condition', 'liquid_levels_condition',
                'other_parts_condition',
            ];

            foreach ($ratings as $column) {
                $table->enum($column, ['excellent', 'good', 'poor'])->nullable();
            }

            $table->text('other_parts')->nullable();
            $table->text('remarks')->nullable();
            $table->text('supervisor_recommendation')->nullable();
            $table->timestamps();

            $table->index(['vehicle_id', 'inspection_date'], 'pm_vehicle_date_idx');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('preventive_maintenance_checklists');
    }
};