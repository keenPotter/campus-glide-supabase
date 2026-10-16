# CampusGlide

A web-based fleet management system for NVSU's motor pool, built as a capstone project.

> ⚠️ **Work in progress** — this README will be updated as development continues.

## Overview

CampusGlide digitizes the request, scheduling, and approval workflow for university-owned vehicles, replacing the manual Trip Ticket process. It covers vehicle requests, trip scheduling, maintenance monitoring, and vehicle-driver allocation.

## Tech Stack

- **Frontend:** Vue.js + Vite, Tailwind CSS
- **Backend:** Laravel + Sanctum
- **Database:** MySQL

## Modules

| Module | Description | Status |
|---|---|---|
| Auth / RBAC / Vehicle Request | Login, role-based access, vehicle request submission & approval | 🔧 In progress |
| Trip Scheduling | Scheduling approved trips | 🔧 In progress |
| Maintenance Monitoring | Vehicle maintenance tracking | ⏳ Not started |
| Vehicle-Driver Allocation | Assigning vehicles/drivers to approved trips | ⏳ Not started |

## Getting Started

### Prerequisites

- PHP 8.x, Composer
- Node.js, npm
- MySQL

### Backend Setup

```bash
cd backend
composer install
cp .env.example .env
php artisan key:generate
php artisan migrate
php artisan serve
```

### Frontend Setup

```bash
cd frontend
npm install
npm run dev
```

## Branching Strategy

- `main` — stable, release-ready code
- `develop` — integration branch for all in-progress module work
- `feature/<module>-<layer>` — individual work branches (e.g. `feature/vehicle-request-backend`)

**Workflow:** branch off `develop` → commit your work → push → open a PR into `develop`. Never push directly to `main`.

## API Documentation

API contract templates are located in `docs/api/`.

## Team

| Name | Module(s) |
|---|---|
| Keen Potter H. Ngamoy | Vehicle Request |
| _(teammate)_ | Trip Scheduling |
| _(teammate)_ | Maintenance Monitoring |
| _(teammate)_ | Vehicle-Driver Allocation |

## TODO

- [ ] Finalize API documentation for all modules
- [ ] Add database schema diagram
- [ ] Add deployment instructions
- [ ] Add testing instructions
