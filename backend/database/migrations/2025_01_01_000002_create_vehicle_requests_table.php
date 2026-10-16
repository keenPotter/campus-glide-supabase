<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('vehicle_requests', function (Blueprint $table) {
            $table->id();
            $table->foreignId('requester_id')->constrained(table: 'users')->cascadeOnDelete();
            $table->dateTime(column: 'request_date');
            $table->date(column: 'trip_date');
            $table->date(column: 'trip_end_date');
            $table->enum(column: 'trip_type', allowed: ['inclusive', 'exclusive']);
            $table->time(column: 'departure_time');
            $table->string(column: 'destination');
            $table->string(column: 'purpose');
            $table->time(column: 'estimated_return_time');
            $table->string(column: 'passengers');
            $table->integer(column: 'number_of_passengers');
            $table->enum(column: 'status', allowed: ['pending', 'approved', 'disapproved'])->default(value: 'pending');
            $table->string(column: 'disapproval_reason', length: 500)->nullable();
            $table->foreignId(column: 'approved_by')->nullable()->constrained(table: 'users')->nullOnDelete();
            $table->dateTime(column: 'approved_date')->nullable();
            $table->timestamps();

            $table->index(columns: 'requester_id');
            $table->index(columns: 'status');
            $table->index(columns: 'trip_date');
            $table->index(columns: 'trip_type');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('vehicle_requests');
    }
};