# Testing CRUDs

We use Pest for testing. Every CRUD must have a feature test covering validation and persistence.

## ⚠️ Environment Safety

ALWAYS run tests with the following environment variables to ensure the MySQL database is not affected:

```powershell
$env:DB_CONNECTION='sqlite'; $env:DB_DATABASE=':memory:'; php artisan test
```

## Example

```php
test('authenticated user can create an award', function () {
    $user = User::factory()->create();

    $this->actingAs($user)
        ->post(route('dashboard.awards.store'), [
            'title' => 'Best Dev',
            'awarder' => 'ACME Corp',
            'awarded_at' => '2024-01-01',
        ])
        ->assertRedirect();

    expect($user->awards()->count())->toBe(1);
    expect($user->awards()->first()->title)->toBe('Best Dev');
});
```

## Validation Tests

```php
test('award title is required', function () {
    $user = User::factory()->create();

    $this->actingAs($user)
        ->post(route('dashboard.awards.store'), ['title' => ''])
        ->assertSessionHasErrors(['title']);
});
```

## UI Smoke Testing

For visual changes, use the browser tool to check for JavaScript errors or Lighthouse for accessibility scores.



