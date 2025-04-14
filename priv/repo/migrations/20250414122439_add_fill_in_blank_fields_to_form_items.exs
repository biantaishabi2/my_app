defmodule MyApp.Repo.Migrations.AddFillInBlankFieldsToFormItems do
  use Ecto.Migration

  def change do
    alter table(:form_items) do
      add :blank_text, :text
      add :blank_count, :integer
      add :blank_min_length, :integer
      add :blank_max_length, :integer
      add :blank_placeholders, {:array, :string}
      add :blank_sizes, {:array, :integer}
    end
  end
end
