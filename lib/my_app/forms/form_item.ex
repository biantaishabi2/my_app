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
      :rating
      # Add other types as needed
    ]
    
    # 评分控件的最大评分值，默认为5
    field :max_rating, :integer, default: 5
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
    |> cast(attrs, [:label, :description, :type, :order, :required, :validation_rules, :form_id, :max_rating])
    |> validate_required([:label, :type, :order, :required, :form_id])
    |> foreign_key_constraint(:form_id)
    # Add custom validations for type, rules etc.
  end
end 