defmodule MyApp.Forms.Form do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "forms" do
    field :title, :string
    field :description, :string
    # Use Ecto.Enum for status later if preferred
    field :status, Ecto.Enum, values: [:draft, :published, :archived], default: :draft
    
    belongs_to :user, MyApp.Accounts.User, foreign_key: :user_id, type: :id

    has_many :items, MyApp.Forms.FormItem, on_delete: :delete_all
    # has_many :logic_rules, MyApp.Forms.LogicRule, on_delete: :delete_all # Add later if needed

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(form, attrs) do
    form
    |> cast(attrs, [:title, :description, :status, :user_id])
    |> validate_required([:title, :status, :user_id])
    # Add other validations as needed
  end
end 