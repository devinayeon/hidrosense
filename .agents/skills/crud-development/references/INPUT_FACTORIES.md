# Input Factories

Input factories are the atomic unit of our CRUD system. They encapsulate field logic across validation, forms, and data migration.

## Pattern

```php
<?php

namespace App\Cruds\Schema\MyEntity\Inputs;

use App\Cruds\Actions\Validation\LaravelValidationRulesRecipe;
use Juaniquillo\CrudAssistant\Contracts\InputInterface;
use Juaniquillo\CrudAssistant\Inputs\DefaultInput;
use Juaniquillo\InputComponentAction\Bags\DefaultAttributeBag;
use Juaniquillo\InputComponentAction\Recipes\InputComponentRecipe;

class NameFactory
{
    public const NAME = 'name';
    public const LABEL = 'Entity Name';

    public static function make(): InputInterface
    {
        $input = new DefaultInput(self::NAME, self::LABEL);

        self::form($input);
        self::validation($input);

        return $input;
    }

    public static function validation(InputInterface $input): void
    {
        $input->setRecipe(new LaravelValidationRulesRecipe([
            'required',
            'string',
            'max:191'
        ]));
    }

    public static function form(InputInterface $input): void
    {
        $input->setRecipe(
            (new InputComponentRecipe)
                ->setAttributeBag(
                    (new DefaultAttributeBag)
                        ->setInputAttributes([
                            'label' => self::LABEL,
                            'badge' => 'required',
                            'icon' => 'tag',
                            'placeholder' => 'Enter a name...',
                        ])
                )
        );
    }
}
```

## Validation Consistency

When dealing with dates, always use the project standard:
`'after_or_equal:1900-01-01'` to prevent database overflows and ensure uniform behavior.

## Available Recipes

- `LaravelValidationRulesRecipe`: Standard Laravel rules.
- `InputComponentRecipe`: UI attributes for Flux/Backend components.
- `ModelToExportRecipe`: Mapping for JSON resume export.
- `LaravelFactoryRecipe`: Logic for Database Factories.
- `TableRowsRecipe`: Rendering logic for dashboard tables.




