defmodule MyApp.Chat do
  @moduledoc """
  The Chat context.
  """

  import Ecto.Query, warn: false
  alias MyApp.Repo

  alias MyApp.Accounts.User
  alias MyApp.Chat.Conversation
  alias MyApp.Chat.Message

  @doc """
  Returns the list of conversations for a given user, ordered by most recently updated.

  ## Examples

      iex> list_conversations(user)
      [%Conversation{}, ...]

  """
  def list_conversations(%User{} = user) do
    Conversation
    |> where(user_id: ^user.id)
    |> order_by(desc: :updated_at)
    |> Repo.all()
  end

  @doc """
  Gets a single conversation for a given user, preloading messages.

  Raises `Ecto.NoResultsError` if the Conversation does not exist or does not belong to the user.

  ## Examples

      iex> get_conversation_with_messages!(user, 123)
      %Conversation{messages: [%Message{}, ...]}}

      iex> get_conversation_with_messages!(user, 456)
      ** (Ecto.NoResultsError)

  """
  def get_conversation_with_messages!(%User{} = user, id) do
    Conversation
    |> where(user_id: ^user.id)
    |> Repo.get!(id)
    |> Repo.preload(messages: from(m in Message, order_by: :inserted_at))
  end

  @doc """
  Creates a conversation for a given user.

  ## Examples

      iex> create_conversation(user, %{title: "New Chat"})
      {:ok, %Conversation{}}

      iex> create_conversation(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_conversation(%User{} = user, attrs \\ %{}) do
    %Conversation{user_id: user.id}
    |> Conversation.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a conversation.

  ## Examples

      iex> update_conversation(conversation, %{title: "Updated Title"})
      {:ok, %Conversation{}}

      iex> update_conversation(conversation, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_conversation(%Conversation{} = conversation, attrs) do
    conversation
    |> Conversation.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a conversation.

  ## Examples

      iex> delete_conversation(conversation)
      {:ok, %Conversation{}}

      iex> delete_conversation(conversation)
      {:error, %Ecto.Changeset{}}

  """
  def delete_conversation(%Conversation{} = conversation) do
    Repo.delete(conversation)
  end

  @doc """
  Deletes a conversation by ID, checking that it belongs to the given user.

  ## Examples

      iex> delete_conversation(id, user)
      {:ok, %Conversation{}}

      iex> delete_conversation(id, user)
      {:error, :not_found}

  """
  def delete_conversation(id, %User{} = user) do
    conversation = Repo.get_by(Conversation, id: id, user_id: user.id)
    
    if conversation do
      # 使用事务删除对话及其消息
      Repo.transaction(fn ->
        # 先删除关联的消息
        from(m in Message, where: m.conversation_id == ^id)
        |> Repo.delete_all()
        
        # 再删除对话
        Repo.delete(conversation)
      end)
    else
      {:error, :not_found}
    end
  end

  @doc """
  Updates a conversation's title, checking that it belongs to the given user.

  ## Examples

      iex> update_conversation_title(id, "New Title", user)
      {:ok, %Conversation{}}

      iex> update_conversation_title(id, "New Title", user)
      {:error, :not_found}

  """
  def update_conversation_title(id, title, %User{} = user) do
    conversation = Repo.get_by(Conversation, id: id, user_id: user.id)
    
    if conversation do
      update_conversation(conversation, %{title: title})
    else
      {:error, :not_found}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking conversation changes.

  ## Examples

      iex> change_conversation(conversation)
      %Ecto.Changeset{data: %Conversation{}}

  """
  def change_conversation(%Conversation{} = conversation, attrs \\ %{}) do
    Conversation.changeset(conversation, attrs)
  end

  # --- Message Functions ---

  @doc """
  Creates a message for a given conversation.

  ## Examples

      iex> create_message(conversation, %{role: "user", content: "Hello"})
      {:ok, %Message{}}

      iex> create_message(conversation, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_message(%Conversation{} = conversation, attrs \\ %{}) do
    %Message{conversation_id: conversation.id}
    |> Message.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Lists all messages for a given conversation, ordered by insertion time.
  (Usually not needed if preloading with get_conversation_with_messages!)

  ## Examples

      iex> list_messages(conversation)
      [%Message{}, ...]

  """
  def list_messages(%Conversation{} = conversation) do
    Message
    |> where(conversation_id: ^conversation.id)
    |> order_by(:inserted_at)
    |> Repo.all()
  end
end
