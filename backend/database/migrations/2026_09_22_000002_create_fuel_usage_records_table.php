<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('fuel_usage_records', function (Blueprint $table) {
            $table->id();
            $table->foreignId('vehicle_id')->constrained('vehicles')->restrictOnDelete();
            $table->foreignId('trip_id')->nullable()->constrained('trips')->nullOnDelete();
            $table->date('record_date');
            $table->decimal('balance_in_tank', 10, 2)->default(0);
            $table->decimal('issuance_from_stock', 10, 2)->default(0);
            $table->decimal('fuel_purchased', 10, 2)->default(0);
            $table->decimal('fuel_used', 10, 2)->default(0);
            $table->decimal('end_trip_balance', 10, 2)->default(0);
            $table->string('riv_no', 100)->nullable();
            $table->date('riv_date')->nullable();
            $table->string('or_no', 100)->nullable();
            $table->date('or_date')->nullable();
            $table->decimal('lubricating_oil', 10, 2)->nullable();
            $table->decimal('diesel_water', 10, 2)->nullable();
            $table->decimal('gear_oil', 10, 2)->nullable();
            $table->decimal('brake_fluid', 10, 2)->nullable();
            $table->decimal('flushing_oil', 10, 2)->nullable();
            $table->decimal('grease', 10, 2)->nullable();
            $table->string('drivers', 500)->nullable();
            $table->timestamps();

            $table->index(['vehicle_id', 'record_date']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('fuel_usage_records');
    }
};