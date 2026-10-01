# CRUD Schemas

The CRUD Schema class orchestrates input factories and defines the visual structure of forms and tables using the `BackendComponent` system and Livewire form renderers.

## Implementation

```php
<?php

namespace App\Cruds\Schema\MyEntity;

use App\Cruds\Concerns\HasHtmlForm;
use App\Cruds\Concerns\HasHtmlTable;
use App\Cruds\Concerns\IsCrud;
use App\Cruds\Contracts\CrudForm;
use App\Cruds\Contracts\CrudInterface;
use App\Cruds\Contracts\CrudTable;
use App\Cruds\Schema\MyEntity\Inputs\NameFactory;
use App\Cruds\Schema\MyEntity\Renderers\MyEntityLivewireFormRenderer;
use Juaniquillo\BackendComponents\Contracts\BackendComponent;
use Juaniquillo\BackendComponents\Contracts\CompoundComponent;

final class MyEntityCrud implements CrudForm, CrudInterface, CrudTable
{
    use HasHtmlForm, HasHtmlTable, IsCrud;

    public function __construct(
        protected ?array $values = null,
        protected ?array $errors = null,
        protected mixed $formRenderer = null,
    ) {}

    public static function build(
        ?array $values = null,
        ?array $errors = null,
        mixed $formRenderer = null,
    ): self {
        return new self($values, $errors, $formRenderer ?? MyEntityLivewireFormRenderer::make());
    }

    public function inputsArray(): array
    {
        return [
            NameFactory::NAME => NameFactory::make(),
        ];
    }

    public function form(?array $inputs = null): BackendComponent|CompoundComponent
    {
        if ($this->formRenderer) {
            return $this->formRenderer->renderFull($this, ['description']);
        }

        return $this->formFullSpanInputs(['description']);
    }
}
```

## Advanced Formatting

Use `fieldsetWrap()` to group related inputs with a title and border:

```php
$this->fieldsetWrap([
    'field_1' => Factory1::make(),
    $this->separator('sep1'),
    'field_2' => Factory2::make(),
], 'group_id', 'Group Title');
```

## Traits

- `HasHtmlForm`: Orchestrates `BackendComponent` form generation.
- `HasHtmlTable`: Orchestrates `BackendComponent` table generation.
- `IsCrud`: Provides context (model, values, errors) to the schema.

## CRUD Schema Renderers & Livewire Integration
When building Livewire CRUDs, use dedicated Livewire Form Renderers (`*LivewireFormRenderer`) and constructor factories (`build()`) to pass form values and validation errors directly to the schema for reactive rendering.
