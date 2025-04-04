defmodule MyApp.Repo.Migrations.AddDescriptionToFormItems do
  use Ecto.Migration

  def change do
    alter table(:form_items) do
      add :description, :text, null: true
    end
  end
end
