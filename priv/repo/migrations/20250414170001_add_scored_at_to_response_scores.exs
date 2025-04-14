defmodule MyApp.Repo.Migrations.AddScoredAtToResponseScores do
  use Ecto.Migration

  def change do
    alter table(:response_scores) do
      # Match the type used in the schema
      add :scored_at, :utc_datetime_usec
    end
  end
end
