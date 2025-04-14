defmodule MyApp.Repo.Migrations.AddMaxScoreToResponseScores do
  use Ecto.Migration

  def change do
    alter table(:response_scores) do
      add :max_score, :integer
    end
  end
end
