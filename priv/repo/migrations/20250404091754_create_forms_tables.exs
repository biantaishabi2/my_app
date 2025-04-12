defmodule MyApp.Repo.Migrations.CreateFormsTables do
  use Ecto.Migration

  def change do
    create table(:forms, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      # Changed to :text for potentially longer descriptions
      add :description, :text
      # Using string for enum, ensure consistency with schema
      add :status, :string, null: false, default: "draft"
      add :form_template_id, references(:form_templates, on_delete: :restrict), null: false
      add :form_data, :map, default: %{}, null: false
      add :created_by_id, references(:users, on_delete: :nothing)
      add :updated_by_id, references(:users, on_delete: :nothing)

      timestamps()
    end

    create index(:forms, [:form_template_id])
    create index(:forms, [:created_by_id])
    create index(:forms, [:updated_by_id])
    create index(:forms, [:status])
  end
end
