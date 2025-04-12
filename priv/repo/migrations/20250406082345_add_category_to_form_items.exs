defmodule MyApp.Repo.Migrations.AddCategoryToFormItems do
  use Ecto.Migration

  def change do
    alter table(:form_items) do
      add :category, :string, default: "basic"
    end

    # 创建索引以提高按类别查询的性能
    create index(:form_items, [:category])

    # 更新类型check约束，加入category枚举值
    execute(
      "ALTER TABLE form_items DROP CONSTRAINT IF EXISTS form_items_category_check",
      ""
    )

    execute(
      "ALTER TABLE form_items ADD CONSTRAINT form_items_category_check CHECK (category::text = ANY (ARRAY['basic'::character varying, 'personal'::character varying, 'advanced'::character varying]::text[]))",
      ""
    )
  end
end
