defmodule MyApp.Repo.Migrations.AddScoreDetailsToResponseScores do
  use Ecto.Migration

  def change do
    alter table(:response_scores) do
      add :score_details, :map
    end
  end
end
