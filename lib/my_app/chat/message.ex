defmodule MyApp.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  alias MyApp.Chat.Conversation

  schema "messages" do
    field :role, :string
    field :content, :string
    belongs_to :conversation, Conversation

    timestamps()
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:role, :content])
    |> validate_required([:conversation_id, :role, :content])
    |> validate_inclusion(:role, ["user", "assistant"])
  end
end 