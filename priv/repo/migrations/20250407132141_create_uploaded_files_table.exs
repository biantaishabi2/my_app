defmodule MyApp.Repo.Migrations.CreateUploadedFilesTable do
  use Ecto.Migration

  def change do
    create table(:uploaded_files, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :form_id, references(:forms, type: :binary_id, on_delete: :delete_all), null: false
      add :form_item_id, references(:form_items, type: :binary_id, on_delete: :delete_all), null: false
      add :response_id, references(:responses, type: :binary_id, on_delete: :nilify_all)
      
      add :original_filename, :string, null: false
      add :filename, :string, null: false
      add :path, :string, null: false
      add :size, :integer, null: false
      add :content_type, :string, null: false
      
      timestamps()
    end

    create index(:uploaded_files, [:form_id])
    create index(:uploaded_files, [:form_item_id])
    create index(:uploaded_files, [:response_id])
    create index(:uploaded_files, [:form_id, :form_item_id])
  end
end
