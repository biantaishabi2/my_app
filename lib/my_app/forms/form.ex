defmodule MyApp.Forms.Form do
  use Ecto.Schema
  import Ecto.Changeset

  alias MyApp.FormTemplates.FormTemplate

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "forms" do
    field :title, :string
    field :description, :string
    # Use Ecto.Enum for status later if preferred
    field :status, Ecto.Enum, values: [:draft, :published, :archived], default: :draft

    belongs_to :user, MyApp.Accounts.User, foreign_key: :user_id, type: :id

    # 添加与 FormTemplate 的关联
    belongs_to :form_template, FormTemplate, type: :binary_id

    # 添加默认页面关联
    belongs_to :default_page, MyApp.Forms.FormPage

    # 添加页面关联
    has_many :pages, MyApp.Forms.FormPage, on_delete: :delete_all
    has_many :items, MyApp.Forms.FormItem, on_delete: :delete_all
    # has_many :logic_rules, MyApp.Forms.LogicRule, on_delete: :delete_all # Add later if needed

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(form, attrs) do
    form
    |> cast(attrs, [:title, :description, :status, :user_id, :default_page_id, :form_template_id])
    |> validate_required([:title, :status, :user_id])
    |> foreign_key_constraint(:default_page_id)
    |> foreign_key_constraint(:form_template_id)

    # Add other validations as needed
  end
end
