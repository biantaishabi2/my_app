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
      :phone
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
      :max_rating, :min, :max, :step, :show_format_hint, :format_display
    ])
    |> validate_required([:label, :type, :order, :required, :form_id])
    |> foreign_key_constraint(:form_id)
    |> validate_number_field_attributes()
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
end 