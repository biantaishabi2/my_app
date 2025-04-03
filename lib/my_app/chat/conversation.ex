defmodule MyApp.Chat.Conversation do
  use Ecto.Schema
  import Ecto.Changeset

  alias MyApp.Accounts.User
  alias MyApp.Chat.Message # 需要先定义 Message 模块

  schema "conversations" do
    field :title, :string
    belongs_to :user, User
    has_many :messages, Message, foreign_key: :conversation_id # 明确外键

    timestamps()
  end

  @doc false
  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:title]) # 只允许修改 title
    |> validate_required([:user_id]) # user_id 是必需的
  end
end
