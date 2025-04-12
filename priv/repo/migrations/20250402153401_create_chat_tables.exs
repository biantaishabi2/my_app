defmodule MyApp.Repo.Migrations.CreateChatTables do
  use Ecto.Migration

  def change do
    create table(:conversations) do
      add :title, :string
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:conversations, [:user_id])

    create table(:messages) do
      add :role, :string, null: false
      add :content, :text, null: false
      add :conversation_id, references(:conversations, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:messages, [:conversation_id])
  end
end
