defmodule MyApp.Repo.Migrations.AddDecorationToFormTemplates do
  use Ecto.Migration

  def change do
    alter table(:form_templates) do
      add :decoration, :jsonb, default: "[]"
    end
  end
end
