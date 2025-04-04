defmodule MyApp.Forms.FormItem do
  use Ecto.Schema
  import Ecto.Changeset

  alias MyApp.Forms.Form
  alias MyApp.Forms.ItemOption

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "form_items" do
    field :label, :string
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
    |> cast(attrs, [:label, :type, :order, :required, :validation_rules, :form_id])
    |> validate_required([:label, :type, :order, :required, :form_id])
    |> foreign_key_constraint(:form_id)
    # Add custom validations for type, rules etc.
  end
end 