<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('trips', function (Blueprint $table) {
            $table->id();
            $table->foreignId('vehicle_request_id')->unique()->constrained('vehicle_requests')->cascadeOnDelete();
            $table->foreignId('vehicle_id')->constrained('vehicles')->restrictOnDelete();
            $table->foreignId('driver_id')->constrained('drivers')->restrictOnDelete();
            $table->date('trip_date');
            $table->time('departure_time');
            $table->time('estimated_return_time')->nullable();
            $table->string('destination');
            $table->string('purpose');
            $table->enum('trip_status', ['scheduled', 'in_progress', 'completed'])->default('scheduled');
            $table->time('actual_departure_time')->nullable();
            $table->time('actual_return_time')->nullable();
            $table->integer('actual_mileage')->nullable();
            $table->string('notes', 500)->nullable();
            $table->timestamps();

            $table->index('trip_date');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('trips');
    }
};