defmodule MyApp.Repo.Migrations.CreateFormTemplates do
  use Ecto.Migration

  def change do
    create table(:form_templates, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :structure, :map, null: false
      add :is_active, :boolean, default: true, null: false
      add :created_by_id, references(:users, on_delete: :nothing)
      add :updated_by_id, references(:users, on_delete: :nothing)

      timestamps()
    end

    create index(:form_templates, [:created_by_id])
    create index(:form_templates, [:updated_by_id])
    create index(:form_templates, [:is_active])
    create unique_index(:form_templates, [:name])
  end
end
