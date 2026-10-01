---
name: crud-development
description: Guide for creating and extending CRUD modules in this project. Use when the user asks to "create a new section", "add a CRUD", "implement a form for X", or "add fields to Y". Covers migrations, models, input factories, CRUD schemas, actions, Livewire components, and views.
---

# CRUD Development Skill

This skill provides a standardized workflow for building CRUD (Create, Read, Update, Delete) modules using the project's modern Livewire 4 + Flux UI architecture and schema-driven design.

## Overview

The project uses a modular "Schema-driven" CRUD system. Instead of defining forms and validation rules in multiple places, we define them once in a **CRUD Schema** using **Input Factories**, rendered via dedicated Livewire form renderers and interactive Livewire components.

## Directory Structure

A full CRUD module in `app/` and `resources/views/` typically involves:

```text
app/
├── Actions/Resume/{Entity}/      # Business logic (Create/Update actions)
├── Cruds/
│   ├── Actions/General/          # NameValueAction / edit / populate actions
│   └── Schema/{Entity}/          # CRUD Schema, Input Factories, and Renderers
│       ├── Inputs/               # Individual field input factories
│       ├── Renderers/            # EntityLivewireFormRenderer, etc.
│       └── {Entity}Crud.php      # Main CRUD schema definition
├── Http/Controllers/             # Thin controllers rendering container views
├── Livewire/Resume/{Entity}/     # Livewire components (Create, Edit, Delete, Table)
│   ├── Create{Entity}.php
│   ├── Edit{Entity}.php
│   ├── Delete{Entity}.php
│   └── {Entity}Table.php
├── Models/                       # Eloquent models
database/
└── migrations/                   # Database tables
resources/views/
├── dashboard/{entity}/           # Blade views for dashboard container & Livewire components
```

## Workflow

### 1. Database & Model
- Create the migration: `php artisan make:migration create_{table}_table`.
- Create the model: `php artisan make:model {Entity}`.
- Use traits: `Uuidable`, `InvalidatesResumeCache` (mandatory if it affects the public resume), `HasHighlights`, etc.
- Ensure all models have proper DocBlocks with `@property-read` for all columns.

### 2. Input Factories
Each field must have an Input Factory in `app/Cruds/Schema/{Entity}/Inputs/`.
Factories define:
- **Validation**: Rules (using `LaravelValidationRulesRecipe`), labels, and custom messages.
- **Form**: UI attributes (label, icon, placeholder, badge) using `InputComponentRecipe`.
- **Consistency**: Reuse existing factories (`UrlFactory`, `DateFactory`, etc.) when possible.

### 3. CRUD Schema & Form Renderers
Create a class in `app/Cruds/Schema/{Entity}/{Entity}Crud.php`.
- Implement `CrudForm`, `CrudTable`, and `CrudInterface`.
- Use `HasHtmlForm`, `HasHtmlTable`, and `IsCrud` traits.
- Define `inputsArray()` returning the factory instances.
- Use dedicated **Form Renderers** (`*LivewireFormRenderer`) extending or using helper renderers to construct the form UI (e.g. `renderFull`, `fieldsetWrap`).

### 4. Actions
Implement persistence in `app/Actions/Resume/{Entity}/`:
- `Create{Entity}`: Handles creation.
- `Update{Entity}`: Handles updates.
- Use PHP 8.4 property promotion and `FormHelpers::convertEmptyStringToNull()` where needed.

### 5. Livewire CRUD Components
Modern CRUD modules are fully built with Livewire 4 components:
- **`Create{Entity}`**: Modal form for creating new records. Uses `IsLivewireForm`, `IsLivewireModal`. Validates via `validateForm($this->crud()->make(), $this->values)` and executes action.
- **`Edit{Entity}`**: Modal form for editing existing records. Populates values using `NameValueAction` or model attributes on mount/edit.
- **`Delete{Entity}`**: Confirmation modal/action to delete records safely.
- **`{Entity}Table`**: Renders records in a table using `IsLivewireTable` or `TableUtil`, dispatching/listening to `resume-updated`.

### 6. Controller & Views
- Controllers should be thin, only rendering the dashboard container view.
- Dashboard views include the Livewire components (e.g., `<livewire:resume.{entity}.create-{entity} />`, `<livewire:resume.{entity}.{entity}-table />`).
- Add the module to `app/Components/Nav/DashboardNav.php`.

For detailed patterns and code examples, see:
- [MIGRATIONS_AND_MODELS.md](references/MIGRATIONS_AND_MODELS.md)
- [INPUT_FACTORIES.md](references/INPUT_FACTORIES.md)
- [CRUD_SCHEMAS.md](references/CRUD_SCHEMAS.md)
- [ACTIONS_AND_CONTROLLERS.md](references/ACTIONS_AND_CONTROLLERS.md)
- [LIVEWIRE_CRUD.md](references/LIVEWIRE_CRUD.md)
- [TESTING.md](references/TESTING.md)
