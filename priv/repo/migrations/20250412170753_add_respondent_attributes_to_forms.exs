defmodule MyApp.Repo.Migrations.AddRespondentAttributesToForms do
  use Ecto.Migration

  def change do
    alter table(:forms) do
      add :respondent_attributes, {:array, :map}, default: []
    end
  end
end
