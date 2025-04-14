defmodule MyApp.Repo.Migrations.RenameTotalScoreToScoreInResponseScores do
  use Ecto.Migration

  def change do
    rename table(:response_scores), :total_score, to: :score
  end
end
