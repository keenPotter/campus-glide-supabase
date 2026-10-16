<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('reschedule_requests')) {
            return;
        }

        // One table for two cases:
        //  - Faculty: "request for date change" (status pending, then approved by the administrator)
        //  - Administrator: direct date change with a reason (status approved right away)
        // A cancelled request is deleted, so 'cancelled' is kept only for old data.
        Schema::create('reschedule_requests', function (Blueprint $table) {
            $table->id();
            $table->foreignId('trip_id')->constrained('trips')->cascadeOnDelete();
            $table->foreignId('requested_by')->constrained('users')->restrictOnDelete();
            $table->date('old_date');
            $table->date('new_date');
            $table->string('reason', 500);
            $table->enum('status', ['pending', 'approved', 'cancelled'])->default('pending');
            $table->foreignId('handled_by')->nullable()->constrained('users')->nullOnDelete();
            $table->string('admin_reason', 500)->nullable();
            $table->dateTime('handled_at')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('reschedule_requests');
    }
};