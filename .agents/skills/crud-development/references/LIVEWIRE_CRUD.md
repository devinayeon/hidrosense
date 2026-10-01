# Livewire CRUD Modules

Modern CRUD modules in this application are built as Livewire 4 components using Flux UI modals, CRUD schemas, input factories, and actions.

## Standard Component Suite

Every CRUD section consists of:
1. **`Create{Entity}`**: Modal component containing the creation form.
2. **`Edit{Entity}`**: Modal component containing the update form populated with existing record data.
3. **`Delete{Entity}`**: Modal/confirmation component to delete records.
4. **`{Entity}Table`**: Component displaying the table list of records with actions to trigger edit/delete modals.

## 1. Create Component Example

```php
<?php

namespace App\Livewire\Resume\MyEntity;

use App\Actions\Resume\MyEntity\CreateMyEntity;
use App\Cruds\Actions\General\NameValueAction;
use App\Cruds\Schema\MyEntity\MyEntityCrud;
use App\Cruds\Schema\MyEntity\Renderers\MyEntityLivewireFormRenderer;
use App\Livewire\Concerns\IsLivewireForm;
use App\Livewire\Concerns\IsLivewireModal;
use App\Models\User;
use Flux\FluxManager;
use Illuminate\Support\Facades\Auth;
use Juaniquillo\BackendComponents\Builders\ComponentBuilder;
use Juaniquillo\BackendComponents\Contracts\BackendComponent;
use Juaniquillo\BackendComponents\Contracts\CompoundComponent;
use Juaniquillo\BackendComponents\Enums\ComponentEnum;
use Livewire\Attributes\Computed;
use Livewire\Component;

class CreateMyEntity extends Component
{
    use IsLivewireForm, IsLivewireModal;

    public array $values = [];

    public function mount(): void
    {
        $this->refreshVariables();
    }

    public function createForm(): void
    {
        /** @var User $user */
        $user = Auth::user();

        $validator = $this->validateForm($this->crud()->make(), $this->values);

        (new CreateMyEntityAction(
            $validator->validated(),
            $user
        ))->handle();

        session()->flash('success', 'Created successfully.');

        $this->dispatch('resume-updated');
        $this->refreshVariables();

        (new FluxManager)->modal($this->getModalKey())->close();
    }

    #[Computed]
    public function refreshVariables(): void
    {
        $output = $this->crud()
            ->make()
            ->execute(
                (new NameValueAction(values: []))
                    ->setGlobalDefault('')
            );

        $this->values = $output->toArray();
    }

    private function crud()
    {
        return MyEntityCrud::build(
            values: $this->values,
            errors: $this->formErrors,
            formRenderer: MyEntityLivewireFormRenderer::make(),
        );
    }

    public function getForm(): BackendComponent|CompoundComponent
    {
        return $this->crud()
            ->form()
            ->setAttribute('wire:submit.prevent', 'createForm()');
    }

    public function getModalKey(): string
    {
        return 'create-my-entity';
    }

    public function getModal(): BackendComponent|CompoundComponent
    {
        $id = $this->getModalKey();
        $form = $this->getForm();

        return ComponentBuilder::make(ComponentEnum::COLLECTION)
            ->setContents([
                'button' => $this->modalButton(
                    label: 'Create Item',
                    id: $id,
                    variant: 'filled',
                    icon: self::CREATE_ICON,
                ),
                'modal' => $this->modalComponent(
                    id: $id,
                    content: $form,
                    themes: ['modal' => 'lg']
                ),
            ]);
    }

    public function render()
    {
        return view('livewire.resume.my-entity.create-my-entity')
            ->with('create', $this->getModal());
    }
}
```

## 2. Key Traits & Conventions

- **`IsLivewireForm`**: Provides `validateForm()`, `$formErrors`, and error handling integration with CRUD schemas.
- **`IsLivewireModal`**: Provides helper methods `modalButton()` and `modalComponent()` leveraging Flux UI modals.
- **Events**: Dispatch `resume-updated` on success so that other components (like tables, preview iframe, and public resume caches) stay in sync.
