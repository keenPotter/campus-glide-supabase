<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // If campusglide_db.sql was already imported, the table exists.
        if (Schema::hasTable('allocations')) {
            return;
        }

        Schema::create('allocations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('trip_id')->unique()->constrained('trips')->cascadeOnDelete();
            $table->foreignId('vehicle_id')->constrained('vehicles')->restrictOnDelete();
            $table->foreignId('driver_id')->constrained('drivers')->restrictOnDelete();
            $table->foreignId('allocated_by')->constrained('users')->restrictOnDelete();
            $table->dateTime('allocation_date');
            $table->string('notes', 500)->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('allocations');
    }
};