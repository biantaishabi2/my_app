defmodule MyApp.Forms.FormItem do
  use Ecto.Schema
  import Ecto.Changeset

  alias MyApp.Forms.Form
  alias MyApp.Forms.ItemOption

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "form_items" do
    field :label, :string
    field :description, :string # 添加描述字段，用于显示表单项的附加说明
    # Use Ecto.Enum for type later if preferred
    field :type, Ecto.Enum, values: [
      :text_input,
      :textarea,
      :radio,
      :checkbox,
      :dropdown,
      :rating,
      :number,
      :email,
      :phone,
      :date,
      :time,
      :region,
      :matrix
      # Add other types as needed
    ]
    
    # 评分控件的最大评分值，默认为5
    field :max_rating, :integer, default: 5
    
    # 数字输入控件属性
    field :min, :integer
    field :max, :integer
    field :step, :integer, default: 1
    
    # 邮箱输入控件属性
    field :show_format_hint, :boolean, default: false
    
    # 电话输入控件属性
    field :format_display, :boolean, default: false
    
    # 日期选择控件属性
    field :min_date, :string
    field :max_date, :string
    field :date_format, :string, default: "yyyy-MM-dd"
    
    # 时间选择控件属性
    field :min_time, :string
    field :max_time, :string
    field :time_format, :string, default: "24h"
    
    # 地区选择控件属性
    field :region_level, :integer, default: 3
    field :default_province, :string
    
    # 矩阵题控件属性
    field :matrix_rows, {:array, :string}, default: []
    field :matrix_columns, {:array, :string}, default: []
    field :matrix_type, Ecto.Enum, values: [:single, :multiple], default: :single
    
    field :order, :integer
    field :required, :boolean, default: false
    field :validation_rules, :map, default: %{} # Store rules as JSONB or Map

    belongs_to :form, Form
    has_many :options, ItemOption, on_delete: :delete_all

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(item, attrs) do
    item
    |> cast(attrs, [
      :label, :description, :type, :order, :required, :validation_rules, :form_id, 
      :max_rating, :min, :max, :step, :show_format_hint, :format_display,
      :min_date, :max_date, :date_format, :min_time, :max_time, :time_format,
      :region_level, :default_province, :matrix_rows, :matrix_columns, :matrix_type
    ])
    |> validate_required([:label, :type, :order, :required, :form_id])
    |> foreign_key_constraint(:form_id)
    |> validate_number_field_attributes()
    |> validate_date_field_attributes()
    |> validate_time_field_attributes()
    |> validate_region_field_attributes()
    |> validate_matrix_field_attributes()
    # Add custom validations for type, rules etc.
  end
  
  # 验证数字输入控件的属性
  defp validate_number_field_attributes(changeset) do
    if get_field(changeset, :type) == :number do
      min = get_field(changeset, :min)
      max = get_field(changeset, :max)
      step = get_field(changeset, :step)
      
      changeset = cond do
        is_nil(min) or is_nil(max) -> 
          changeset
        min > max -> 
          add_error(changeset, :min, "最小值不能大于最大值")
        true -> 
          changeset
      end
      
      changeset = if not is_nil(step) and step <= 0 do
        add_error(changeset, :step, "步长必须大于0")
      else
        changeset
      end
      
      changeset
    else
      changeset
    end
  end
  
  # 验证日期选择控件的属性
  defp validate_date_field_attributes(changeset) do
    if get_field(changeset, :type) == :date do
      date_format = get_field(changeset, :date_format)
      
      # 验证日期格式
      changeset = if date_format && !Regex.match?(~r/^[yMd\-\/\.\s]+$/, date_format) do
        add_error(changeset, :date_format, "日期格式无效")
      else
        changeset
      end
      
      changeset
    else
      changeset
    end
  end
  
  # 验证时间选择控件的属性
  defp validate_time_field_attributes(changeset) do
    if get_field(changeset, :type) == :time do
      min_time = get_field(changeset, :min_time)
      max_time = get_field(changeset, :max_time)
      
      # 验证时间范围
      changeset = cond do
        is_nil(min_time) or is_nil(max_time) -> 
          changeset
        compare_times(min_time, max_time) > 0 -> 
          add_error(changeset, :min_time, "开始时间不能晚于结束时间")
        true -> 
          changeset
      end
      
      changeset
    else
      changeset
    end
  end
  
  # 验证地区选择控件的属性
  defp validate_region_field_attributes(changeset) do
    if get_field(changeset, :type) == :region do
      region_level = get_field(changeset, :region_level)
      
      # 验证地区级别
      changeset = if region_level && (region_level < 1 || region_level > 3) do
        add_error(changeset, :region_level, "地区级别必须是1-3之间的值")
      else
        changeset
      end
      
      changeset
    else
      changeset
    end
  end
  
  # 验证矩阵题控件的属性
  defp validate_matrix_field_attributes(changeset) do
    if get_field(changeset, :type) == :matrix do
      matrix_rows = get_field(changeset, :matrix_rows)
      matrix_columns = get_field(changeset, :matrix_columns)
      
      # 验证行和列必须至少有一个元素
      changeset = cond do
        is_nil(matrix_rows) || length(matrix_rows) == 0 ->
          add_error(changeset, :matrix_rows, "矩阵行不能为空")
        is_nil(matrix_columns) || length(matrix_columns) == 0 ->
          add_error(changeset, :matrix_columns, "矩阵列不能为空")
        true ->
          changeset
      end
      
      # 验证行和列的唯一性
      changeset = if matrix_rows && matrix_columns && 
                    length(matrix_rows) != length(Enum.uniq(matrix_rows)) do
        add_error(changeset, :matrix_rows, "矩阵行标题必须唯一")
      else
        changeset
      end
      
      changeset = if matrix_columns && matrix_columns && 
                    length(matrix_columns) != length(Enum.uniq(matrix_columns)) do
        add_error(changeset, :matrix_columns, "矩阵列标题必须唯一")
      else
        changeset
      end
      
      changeset
    else
      changeset
    end
  end
  
  # 辅助函数：比较两个时间字符串
  defp compare_times(time1, time2) do
    # 转换为24小时制的分钟数进行比较
    [h1, m1] = String.split(time1, ":")
    [h2, m2] = String.split(time2, ":")
    
    minutes1 = String.to_integer(h1) * 60 + String.to_integer(m1)
    minutes2 = String.to_integer(h2) * 60 + String.to_integer(m2)
    
    minutes1 - minutes2
  end
end 