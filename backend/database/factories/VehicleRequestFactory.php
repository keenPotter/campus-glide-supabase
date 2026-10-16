<?php

namespace Database\Factories;

use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

class VehicleRequestFactory extends Factory
{
    public function definition(): array
    {
        $tripDate = fake()->dateTimeBetween('now', '+2 months');
        $tripEndDate = (clone $tripDate)->modify('+' . fake()->numberBetween(0, 3) . ' days');

        return [
            'requester_id' => User::factory()->create(['role' => 'faculty'])->id,
            'request_date' => now(),
            'trip_date' => $tripDate,
            'trip_end_date' => $tripEndDate,
            'departure_time' => fake()->time('H:i'),
            'destination' => fake()->city(),
            'purpose' => fake()->sentence(),
            'trip_type' => fake()->randomElement(['inclusive', 'exclusive']),
            'estimated_return_time' => fake()->time('H:i'),
            'passengers' => fake()->name(),
            'number_of_passengers' => fake()->numberBetween(1, 10),
            'status' => fake()->randomElement(['pending', 'approved', 'disapproved']),
        ];
    }
}