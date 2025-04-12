defmodule MyApp.Forms.FormItem do
  use Ecto.Schema
  import Ecto.Changeset

  alias MyApp.Forms.Form
  alias MyApp.Forms.ItemOption

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "form_items" do
    field :label, :string
    # 添加描述字段，用于显示表单项的附加说明
    field :description, :string
    # 添加 placeholder 字段
    field :placeholder, :string
    # Use Ecto.Enum for type later if preferred
    field :type, Ecto.Enum,
      values: [
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
        :matrix,
        :image_choice,
        :file_upload
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

    # 图片选择控件属性
    field :selection_type, Ecto.Enum, values: [:single, :multiple], default: :single
    field :image_caption_position, Ecto.Enum, values: [:top, :bottom, :none], default: :bottom

    # 文件上传控件属性
    field :allowed_extensions, {:array, :string}, default: []
    # 默认最大文件大小为5MB
    field :max_file_size, :integer, default: 5
    field :multiple_files, :boolean, default: false
    # 默认最多上传1个文件
    field :max_files, :integer, default: 1

    # 控件分类属性
    field :category, Ecto.Enum, values: [:basic, :personal, :advanced], default: :basic

    # 条件逻辑相关字段
    # 存储JSON格式的显示条件
    field :visibility_condition, :string
    # 存储JSON格式的必填条件
    field :required_condition, :string

    field :order, :integer
    field :required, :boolean, default: false
    # Store rules as JSONB or Map
    field :validation_rules, :map, default: %{}

    belongs_to :form, Form
    belongs_to :page, MyApp.Forms.FormPage
    has_many :options, ItemOption, on_delete: :delete_all

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(item, attrs) do
    item
    |> cast(attrs, [
      :label,
      :description,
      :type,
      :order,
      :required,
      :validation_rules,
      :form_id,
      :page_id,
      :max_rating,
      :min,
      :max,
      :step,
      :show_format_hint,
      :format_display,
      :min_date,
      :max_date,
      :date_format,
      :min_time,
      :max_time,
      :time_format,
      :region_level,
      :default_province,
      :matrix_rows,
      :matrix_columns,
      :matrix_type,
      :selection_type,
      :image_caption_position,
      :allowed_extensions,
      :max_file_size,
      :multiple_files,
      :max_files,
      :category,
      :visibility_condition,
      :required_condition
    ])
    |> validate_required([:label, :type, :order, :required, :form_id])
    |> foreign_key_constraint(:form_id)
    |> foreign_key_constraint(:page_id)
    |> validate_number_field_attributes()
    |> validate_date_field_attributes()
    |> validate_time_field_attributes()
    |> validate_region_field_attributes()
    |> validate_matrix_field_attributes()
    |> validate_image_choice_field_attributes()
    |> validate_file_upload_field_attributes()
    |> assign_default_category()

    # Add custom validations for type, rules etc.
  end

  # 根据控件类型自动分配默认类别
  defp assign_default_category(changeset) do
    # 如果已经在参数中设置了类别
    if get_change(changeset, :category) do
      changeset
    else
      # 根据控件类型分配默认类别
      type = get_field(changeset, :type)

      cond do
        # 基础控件类型
        type in [:text_input, :textarea, :radio, :checkbox, :dropdown, :number] ->
          put_change(changeset, :category, :basic)

        # 个人信息控件类型
        type in [:email, :phone, :date, :time, :region] ->
          put_change(changeset, :category, :personal)

        # 高级控件类型
        type in [:rating, :matrix, :image_choice, :file_upload] ->
          put_change(changeset, :category, :advanced)

        # 默认为基础类型
        true ->
          put_change(changeset, :category, :basic)
      end
    end
  end

  # 验证数字输入控件的属性
  defp validate_number_field_attributes(changeset) do
    if get_field(changeset, :type) == :number do
      min = get_field(changeset, :min)
      max = get_field(changeset, :max)
      step = get_field(changeset, :step)

      changeset =
        cond do
          is_nil(min) or is_nil(max) ->
            changeset

          min > max ->
            add_error(changeset, :min, "最小值不能大于最大值")

          true ->
            changeset
        end

      changeset =
        if not is_nil(step) and step <= 0 do
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
      changeset =
        if date_format && !Regex.match?(~r/^[yMd\-\/\.\s]+$/, date_format) do
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
      changeset =
        cond do
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
      changeset =
        if region_level && (region_level < 1 || region_level > 3) do
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
      changeset =
        cond do
          is_nil(matrix_rows) || length(matrix_rows) == 0 ->
            add_error(changeset, :matrix_rows, "矩阵行不能为空")

          is_nil(matrix_columns) || length(matrix_columns) == 0 ->
            add_error(changeset, :matrix_columns, "矩阵列不能为空")

          true ->
            changeset
        end

      # 验证行和列的唯一性
      changeset =
        if matrix_rows && matrix_columns &&
             length(matrix_rows) != length(Enum.uniq(matrix_rows)) do
          add_error(changeset, :matrix_rows, "矩阵行标题必须唯一")
        else
          changeset
        end

      changeset =
        if matrix_columns && matrix_columns &&
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

  # 验证图片选择控件的属性
  defp validate_image_choice_field_attributes(changeset) do
    if get_field(changeset, :type) == :image_choice do
      # 这里暂时不用添加额外验证，因为我们使用了Ecto.Enum
      # selection_type和image_caption_position已经通过Ecto.Enum验证了
      changeset
    else
      changeset
    end
  end

  # 验证文件上传控件的属性
  defp validate_file_upload_field_attributes(changeset) do
    if get_field(changeset, :type) == :file_upload do
      max_file_size = get_field(changeset, :max_file_size)
      allowed_extensions = get_field(changeset, :allowed_extensions)
      multiple_files = get_field(changeset, :multiple_files)
      max_files = get_field(changeset, :max_files)

      # 验证文件大小限制
      changeset =
        cond do
          is_nil(max_file_size) ->
            changeset

          max_file_size <= 0 ->
            add_error(changeset, :max_file_size, "文件大小必须大于0")

          max_file_size > 20 ->
            add_error(changeset, :max_file_size, "单个文件大小不能超过20MB")

          true ->
            changeset
        end

      # 验证文件数量限制
      changeset =
        if multiple_files && max_files do
          cond do
            max_files < 1 ->
              add_error(changeset, :max_files, "最多文件数必须至少为1")

            max_files > 10 ->
              add_error(changeset, :max_files, "最多允许上传10个文件")

            true ->
              changeset
          end
        else
          changeset
        end

      # 验证文件扩展名
      changeset =
        if allowed_extensions && length(allowed_extensions) > 0 do
          invalid_extensions =
            Enum.filter(allowed_extensions, fn ext -> !String.starts_with?(ext, ".") end)

          if length(invalid_extensions) > 0 do
            add_error(changeset, :allowed_extensions, "文件扩展名必须以点号(.)开头")
          else
            changeset
          end
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
