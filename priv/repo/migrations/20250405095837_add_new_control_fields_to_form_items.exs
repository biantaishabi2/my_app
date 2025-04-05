defmodule MyApp.Repo.Migrations.AddNewControlFieldsToFormItems do
  use Ecto.Migration

  def change do
    alter table(:form_items) do
      # 数字输入控件属性
      add :min, :integer
      add :max, :integer
      add :step, :integer, default: 1
      
      # 邮箱输入控件属性
      add :show_format_hint, :boolean, default: false
      
      # 电话输入控件属性
      add :format_display, :boolean, default: false
    end
    
    # 注意：Ecto将枚举类型存储为字符串，所以不需要修改数据库枚举类型
    # 我们只需要在Elixir代码中更新FormItem模型的Ecto.Enum定义
  end
end
