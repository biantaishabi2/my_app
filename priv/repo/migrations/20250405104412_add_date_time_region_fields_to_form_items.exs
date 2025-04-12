defmodule MyApp.Repo.Migrations.AddDateTimeRegionFieldsToFormItems do
  use Ecto.Migration

  def change do
    alter table(:form_items) do
      # 日期选择控件属性
      add :min_date, :string
      add :max_date, :string
      add :date_format, :string, default: "yyyy-MM-dd"

      # 时间选择控件属性
      add :min_time, :string
      add :max_time, :string
      add :time_format, :string, default: "24h"

      # 地区选择控件属性
      add :region_level, :integer, default: 3
      add :default_province, :string
    end

    # 注意：Ecto将枚举类型存储为字符串，所以不需要修改数据库枚举类型
    # 我们只需要在Elixir代码中更新FormItem模型的Ecto.Enum定义
  end
end
