defmodule MyApp.Repo.Migrations.AddMaxRatingToFormItems do
  use Ecto.Migration

  def change do
    alter table(:form_items) do
      add :max_rating, :integer, default: 5
    end
  end
end
