defmodule MyApp.Repo.Migrations.AddVersionToFormTemplates do
  use Ecto.Migration

  def change do
    alter table(:form_templates) do
      add :version, :integer, null: false, default: 1
    end
  end
end
