# Actions & Controllers

We follow the "Thick Actions, Thin Controllers & Livewire Components" pattern to ensure business logic is reusable and testable.

## Actions

Place actions in `app/Actions/Resume/{Entity}/`. Use PHP 8.4 property promotion and `FormHelpers::convertEmptyStringToNull()` when handling user input.

```php
<?php

namespace App\Actions\Resume\MyEntity;

use App\Models\User;
use App\Models\MyEntity;

class CreateMyEntity
{
    public function __construct(
        private array $data,
        private User $user
    ) {}

    public function handle(): MyEntity
    {
        return $this->user->myEntities()->create($this->data);
    }
}
```

## Controllers (Thin Dashboard Controllers)

Controllers in modern Livewire CRUD modules are extremely thin, serving only to render the dashboard container view hosting the Livewire components.

```php
<?php

namespace App\Http\Controllers;

class MyEntityController extends Controller
{
    public function __invoke()
    {
        return view('dashboard.my-entities.index');
    }
}
```

## Livewire Integration for Forms & Validation

Instead of traditional FormRequests, validation is handled in Livewire components using `IsLivewireForm` and the CRUD schema:

```php
$validator = $this->validateForm($this->crud()->make(), $this->values);
$data = FormHelpers::convertEmptyStringToNull($validator->validated());
```
