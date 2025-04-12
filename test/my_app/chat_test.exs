defmodule MyApp.ChatTest do
  use MyApp.DataCase

  alias MyApp.Chat

  describe "conversations" do
    alias MyApp.Chat.Conversation

    import MyApp.ChatFixtures

    @invalid_attrs %{messages: nil, title: nil, role: nil, Message: nil, content: nil}

    test "list_conversations/0 returns all conversations" do
      conversation = conversation_fixture()
      assert Chat.list_conversations() == [conversation]
    end

    test "get_conversation!/1 returns the conversation with given id" do
      conversation = conversation_fixture()
      assert Chat.get_conversation!(conversation.id) == conversation
    end

    test "create_conversation/1 with valid data creates a conversation" do
      valid_attrs = %{
        messages: "some messages",
        title: "some title",
        role: "some role",
        Message: "some Message",
        content: "some content"
      }

      assert {:ok, %Conversation{} = conversation} = Chat.create_conversation(valid_attrs)
      assert conversation.messages == "some messages"
      assert conversation.title == "some title"
      assert conversation.role == "some role"
      assert conversation.Message == "some Message"
      assert conversation.content == "some content"
    end

    test "create_conversation/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Chat.create_conversation(@invalid_attrs)
    end

    test "update_conversation/2 with valid data updates the conversation" do
      conversation = conversation_fixture()

      update_attrs = %{
        messages: "some updated messages",
        title: "some updated title",
        role: "some updated role",
        Message: "some updated Message",
        content: "some updated content"
      }

      assert {:ok, %Conversation{} = conversation} =
               Chat.update_conversation(conversation, update_attrs)

      assert conversation.messages == "some updated messages"
      assert conversation.title == "some updated title"
      assert conversation.role == "some updated role"
      assert conversation.Message == "some updated Message"
      assert conversation.content == "some updated content"
    end

    test "update_conversation/2 with invalid data returns error changeset" do
      conversation = conversation_fixture()
      assert {:error, %Ecto.Changeset{}} = Chat.update_conversation(conversation, @invalid_attrs)
      assert conversation == Chat.get_conversation!(conversation.id)
    end

    test "delete_conversation/1 deletes the conversation" do
      conversation = conversation_fixture()
      assert {:ok, %Conversation{}} = Chat.delete_conversation(conversation)
      assert_raise Ecto.NoResultsError, fn -> Chat.get_conversation!(conversation.id) end
    end

    test "change_conversation/1 returns a conversation changeset" do
      conversation = conversation_fixture()
      assert %Ecto.Changeset{} = Chat.change_conversation(conversation)
    end
  end
end
