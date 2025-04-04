defmodule MyApp.Repo.Migrations.CreateFormsTables do
  use Ecto.Migration

  def change do
    create table(:forms, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :description, :text # Changed to :text for potentially longer descriptions
      add :status, :string, null: false, default: "draft" # Using string for enum, ensure consistency with schema

      timestamps()
    end

    create table(:form_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :label, :string, null: false
      add :type, :string, null: false # Using string for enum
      add :order, :integer, null: false
      add :required, :boolean, default: false, null: false
      add :validation_rules, :map, default: %{} # Maps to JSONB usually
      add :form_id, references(:forms, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end
    # Index for efficient lookup of items by form
    create index(:form_items, [:form_id])
    # Optional: Index for ordering items within a form
    # create index(:form_items, [:form_id, :order])

    create table(:item_options, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :label, :string, null: false
      add :value, :string, null: false
      add :order, :integer, null: false
      add :form_item_id, references(:form_items, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end
    # Index for efficient lookup of options by item
    create index(:item_options, [:form_item_id])
    # Optional: Index for ordering options within an item
    # create index(:item_options, [:form_item_id, :order])

  end
end
