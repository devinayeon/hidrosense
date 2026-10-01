# Migrations & Models

## Models

Models must use strict typing and include DocBlocks for PHPStan. Use the `InvalidatesResumeCache` trait for any entity appearing on the resume.

```php
<?php

namespace App\Models;

use App\Models\Concerns\InvalidatesResumeCache;
use App\Models\Concerns\Uuidable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * @property-read int $id
 * @property-read string $uuid
 * @property-read string $name
 * @property-read int $user_id
 * @property-read Carbon|null $created_at
 * @property-read Carbon|null $updated_at
 * @property-read User $user
 */
class MyEntity extends Model
{
    use Uuidable, InvalidatesResumeCache;

    protected $fillable = ['user_id', 'uuid', 'name'];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
```

## Migrations

Always include a foreign key to `users` with `cascadeOnDelete()` and a `uuid` column.

```php
Schema::create('my_entities', function (Blueprint $table) {
    $table->id();
    $table->foreignId('user_id')->constrained()->cascadeOnDelete();
    $table->uuid('uuid')->unique();
    $table->string('name');
    $table->timestamps();
});
```




