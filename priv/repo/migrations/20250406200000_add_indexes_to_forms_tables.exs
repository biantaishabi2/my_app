defmodule MyApp.Repo.Migrations.AddIndexesToFormsTables do
  use Ecto.Migration

  def change do
    # 添加表单项表的索引（如果不存在）
    create_if_not_exists index(:form_items, [:form_id])
    create_if_not_exists index(:form_items, [:page_id])
    
    # 添加表单选项表的索引
    create_if_not_exists index(:item_options, [:form_item_id])
    
    # 添加表单页面表的索引
    create_if_not_exists index(:form_pages, [:form_id])
  end
end