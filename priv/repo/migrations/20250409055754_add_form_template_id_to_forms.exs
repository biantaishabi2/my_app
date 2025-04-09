defmodule MyApp.Repo.Migrations.AddFormTemplateIdToForms do
  use Ecto.Migration

  def change do
    alter table(:forms) do
      # Assuming form_templates table name and binary_id type are correct
      add :form_template_id, references(:form_templates, type: :binary_id, on_delete: :nothing)
    end
  end
end
