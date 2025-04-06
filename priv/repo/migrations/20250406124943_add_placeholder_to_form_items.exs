defmodule MyApp.Repo.Migrations.AddPlaceholderToFormItems do
  use Ecto.Migration

  def change do
    alter table(:form_items) do
      add :placeholder, :string, null: true
    end
  end
end
