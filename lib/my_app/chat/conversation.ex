defmodule MyApp.Chat.Conversation do
  use Ecto.Schema
  import Ecto.Changeset

  alias MyApp.Accounts.User
  # 需要先定义 Message 模块
  alias MyApp.Chat.Message

  schema "conversations" do
    field :title, :string
    belongs_to :user, User
    # 明确外键
    has_many :messages, Message, foreign_key: :conversation_id

    timestamps()
  end

  @doc false
  def changeset(conversation, attrs) do
    conversation
    # 只允许修改 title
    |> cast(attrs, [:title])
    # user_id 是必需的
    |> validate_required([:user_id])
  end
end
