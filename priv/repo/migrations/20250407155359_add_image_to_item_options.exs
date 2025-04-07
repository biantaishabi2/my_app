defmodule MyApp.Repo.Migrations.AddImageToItemOptions do
  use Ecto.Migration

  def change do
    alter table(:item_options) do
      # 添加 image_id 字段，作为指向 uploaded_files 表的外键
      # on_delete: :nilify_all 表示如果关联的 uploaded_files 记录被删除，这里的 image_id 会被设为 nil
      add :image_id, references(:uploaded_files, type: :binary_id, on_delete: :nilify_all)
      
      # 添加 image_filename 字段
      add :image_filename, :string
    end

    # 可以选择为 image_id 创建索引以提高查询性能
    create index(:item_options, [:image_id])
  end
end
