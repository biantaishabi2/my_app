defmodule MyApp.Repo.Migrations.CreateResponsesTables do
  use Ecto.Migration

  def change do
    create table(:responses, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :submitted_at, :utc_datetime_usec, null: false
      add :respondent_info, :map, default: %{}
      add :form_id, references(:forms, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:responses, [:form_id])

    create table(:answers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :value, :map, null: false

      add :response_id, references(:responses, type: :binary_id, on_delete: :delete_all),
        null: false

      add :form_item_id, references(:form_items, type: :binary_id, on_delete: :restrict),
        null: false

      timestamps()
    end

    create index(:answers, [:response_id])
    create index(:answers, [:form_item_id])
  end
end
