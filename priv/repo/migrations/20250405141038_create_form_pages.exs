defmodule MyApp.Repo.Migrations.CreateFormPages do
  use Ecto.Migration

  def change do
    # 1. 创建表单页面表
    create table(:form_pages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :description, :text
      add :order, :integer, null: false
      add :form_id, references(:forms, on_delete: :delete_all, type: :binary_id), null: false

      timestamps()
    end

    create index(:form_pages, [:form_id])

    # 2. 添加page_id到form_items表
    alter table(:form_items) do
      add :page_id, references(:form_pages, on_delete: :nilify_all, type: :binary_id)
    end

    create index(:form_items, [:page_id])

    # 3. 使Form模型和FormPage关联
    alter table(:forms) do
      add :default_page_id, references(:form_pages, on_delete: :nilify_all, type: :binary_id)
    end
  end
end
