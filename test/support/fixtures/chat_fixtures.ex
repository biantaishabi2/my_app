defmodule MyApp.ChatFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `MyApp.Chat` context.
  """

  @doc """
  Generate a conversation.
  """
  def conversation_fixture(attrs \\ %{}) do
    {:ok, conversation} =
      attrs
      |> Enum.into(%{
        Message: "some Message",
        content: "some content",
        messages: "some messages",
        role: "some role",
        title: "some title"
      })
      |> MyApp.Chat.create_conversation()

    conversation
  end
end
