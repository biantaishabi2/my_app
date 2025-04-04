defmodule MyApp.Repo.Migrations.AddUserIdToForms do
  use Ecto.Migration

  def change do
    alter table(:forms) do
      add :user_id, references(:users, on_delete: :delete_all)
    end

    create index(:forms, [:user_id])
  end
end
