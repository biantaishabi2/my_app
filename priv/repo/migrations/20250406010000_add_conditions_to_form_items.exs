defmodule MyApp.Repo.Migrations.AddConditionsToFormItems do
  use Ecto.Migration

  def change do
    alter table(:form_items) do
      # 表单项显示条件 - 存储为JSON字符串
      add :visibility_condition, :text
      
      # 表单项必填条件 - 存储为JSON字符串
      add :required_condition, :text
    end
  end
end