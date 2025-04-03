defmodule MyAppWeb.ChatLive.Index do
  use MyAppWeb, :live_view

  alias MyApp.Chat
  alias MyApp.Chat.Conversation
  # 移除未使用的别名
  # alias MyApp.Chat.Message
  # alias MyApp.Accounts

  on_mount {MyAppWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    conversations = Chat.list_conversations(current_user)

    # 记录挂载事件的调试日志，帮助我们跟踪频率
    IO.puts "MOUNTING ChatLive.Index for user #{current_user.id}"

    # Determine initial conversation and messages
    {current_conversation, messages} = 
      case conversations do
        [] ->
          # No conversations yet, maybe create one or show a prompt
          # For now, let's keep it empty
          {nil, []}
        [first_conversation | _] ->
          # Load the first conversation and its messages
          conv = Chat.get_conversation_with_messages!(current_user, first_conversation.id)
          {conv, conv.messages}
      end

    {:ok, assign(socket,
      conversations: conversations,
      current_conversation: current_conversation, # Store the full conversation struct
      messages: messages,
      message_text: "",
      show_sidebar: true
    )}
  end

  # Handle URL changes if navigating directly to a conversation
  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    current_user = socket.assigns.current_user
    try do
      conversation_id = String.to_integer(id)
      conversation = Chat.get_conversation_with_messages!(current_user, conversation_id)
      {:noreply, assign(socket, current_conversation: conversation, messages: conversation.messages)}
    rescue
      Ecto.NoResultsError ->
        {:noreply, 
          socket
          |> put_flash(:error, "对话不存在或您无权访问。")
          |> push_navigate(to: ~p"/chat")}
      _ -> # Handle other potential errors like invalid ID format
         {:noreply, 
          socket
          |> put_flash(:error, "无效的对话ID。")
          |> push_navigate(to: ~p"/chat")}
    end
  end

  # Handle navigating to the base /chat path
  def handle_params(_params, _uri, socket) do
     # 如果已经有选中的对话，则保持不变
     if socket.assigns[:current_conversation] do
       {:noreply, socket}
     else
       # 只有在没有选中对话时才重新加载和选择第一个对话
       current_user = socket.assigns.current_user
       conversations = Chat.list_conversations(current_user)
       
       {current_conversation, messages} = 
         case conversations do
           [] -> {nil, []}
           [first | _] -> 
             conv = Chat.get_conversation_with_messages!(current_user, first.id)
             {conv, conv.messages}
         end
         
       {:noreply, assign(socket, 
         conversations: conversations, 
         current_conversation: current_conversation,
         messages: messages
       )}
     end
  end

  @impl true
  def handle_event("send_message", %{"message" => content}, socket) when content != "" do
    current_user = socket.assigns.current_user
    current_conversation_maybe_temp = socket.assigns.current_conversation

    # Ensure a conversation is selected or is the temporary new one
    if is_nil(current_conversation_maybe_temp) do
      {:noreply, put_flash(socket, :error, "请先选择或创建一个对话！")}
    else
      # ---- Modification Start: Handle temporary new conversation ----
      persisted_conversation = 
        case current_conversation_maybe_temp.id do
          :new ->
            # This is the first message for a new conversation
            # 1. Create the conversation in the database
            new_conv_attrs = %{title: String.slice(content, 0, 30)} # Use first message as title
            case Chat.create_conversation(current_user, new_conv_attrs) do
              {:ok, new_persisted_conv} ->
                # Return the newly persisted conversation
                new_persisted_conv 
              {:error, changeset} ->
                # Handle error, put flash and return updated socket with error message
                updated_socket = put_flash(socket, :error, "创建对话失败: #{inspect(changeset.errors)}")
                # Save the updated socket to use later
                updated_socket
                # Return nil to signal failure and skip message creation
                nil 
            end
          _ ->
            # It's an existing, persisted conversation
            current_conversation_maybe_temp
        end
      # ---- Modification End ----

      # Proceed only if we have a persisted conversation (either existing or newly created)
      if persisted_conversation do
        # 1. Create the user message (using the persisted conversation)
        {:ok, _user_msg} = Chat.create_message(persisted_conversation, %{role: "user", content: content})

        # 2. Simulate and create AI response
        ai_response_content = generate_ai_response(content)
        {:ok, _ai_msg} = Chat.create_message(persisted_conversation, %{role: "assistant", content: ai_response_content})

        # 3. Reload conversation WITH messages *after* inserts
        reloaded_conv_after_inserts = Chat.get_conversation_with_messages!(current_user, persisted_conversation.id)
        
        # 4. Update timestamp (title update logic moved to creation)
        #    We might not need explicit update if create_message updates parent timestamp
        #    Let's assume Chat.update_conversation mainly handles timestamp refresh if needed
        {:ok, final_updated_conversation} = Chat.update_conversation(reloaded_conv_after_inserts, %{}) # Pass empty map if only timestamp update

        # 5. Reload AGAIN to get final state
        final_reloaded_conversation = Chat.get_conversation_with_messages!(current_user, final_updated_conversation.id)
        
        # 6. Reload the conversation list (now includes the new one if created)
        conversations = Chat.list_conversations(current_user)

        {:noreply, 
          socket
          |> assign( 
             messages: final_reloaded_conversation.messages,
             current_conversation: final_reloaded_conversation, 
             conversations: conversations,
             message_text: "" # 留作调试或状态指示
          )
          |> push_event("clear_message_input", %{}) # <--- 推送清空事件
        }
      else
        # Conversation creation failed, just return the socket with flash
        {:noreply, socket}
      end
    end
  end

  def handle_event("send_message", _, socket), do: {:noreply, socket}

  @impl true
  def handle_event("form_change", %{"message" => message_text}, socket) do
    # 添加调试日志，跟踪form_change事件
    IO.puts "FORM_CHANGE: message_text = #{message_text}"
    
    # 确保只更新message_text，不触发其他状态更改
    {:noreply, socket |> assign(:message_text, message_text)}
  end

  @impl true
  def handle_event("toggle_sidebar", _params, socket) do
    # 记录侧边栏状态变更
    current_state = socket.assigns.show_sidebar
    new_state = !current_state
    IO.puts("Toggling sidebar: #{current_state} -> #{new_state}")
    
    # 推送状态更新到客户端
    socket = 
      socket
      |> assign(show_sidebar: new_state)
      |> push_event("sidebar_toggled", %{show: new_state})
      
    {:noreply, socket}
  end

  @impl true
  def handle_event("new_conversation", _params, socket) do
    current_user = socket.assigns.current_user
    existing_conversations = socket.assigns.conversations # Get current list
    
    # 1. Create a temporary, non-persisted Conversation struct
    temp_new_conv = %Conversation{
      id: :new, # Use atom :new
      title: "新对话...", # Placeholder title
      user_id: current_user.id
      # messages will be empty
    }
    
    # 2. Prepend the temporary conversation to the existing list
    updated_conversations = [temp_new_conv | existing_conversations]
    
    # 3. Assign the updated list, the temporary current conversation, and clear messages
    {:noreply, assign(socket, 
      conversations: updated_conversations, # Assign the list including the new temp one
      current_conversation: temp_new_conv, 
      messages: [], 
      message_text: "" # Clear input
    )}
  end

  @impl true
  def handle_event("select_conversation", %{"id" => id_str}, socket) do
    current_user = socket.assigns.current_user
    # 获取当前的对话列表
    existing_conversations = socket.assigns.conversations
    
    try do
      id = String.to_integer(id_str)
      # 记录会话选择操作
      IO.puts "选择对话: id=#{id}"
      
      # 如果已经选择了这个会话，避免不必要的重新获取
      if socket.assigns.current_conversation && socket.assigns.current_conversation.id == id do
        IO.puts "已经选择了该对话，跳过"
        {:noreply, socket}
      else
        # Fetch the selected conversation with messages
        selected_conv = Chat.get_conversation_with_messages!(current_user, id)
        
        # ---- Modification: Filter out the :new conversation from the current list ----
        updated_conversations = Enum.reject(existing_conversations, &(&1.id == :new))
        # ---- Modification End ----
        
        # Optional: Navigate if you want the URL to reflect the selected chat
        # socket = push_navigate(socket, to: ~p"/chat/#{id}")
        
        {:noreply, assign(socket, 
          current_conversation: selected_conv,
          messages: selected_conv.messages,
          # Use the filtered list
          conversations: updated_conversations,
          # 保留消息输入框内容
          message_text: socket.assigns.message_text
        )}
      end
    rescue
      Ecto.NoResultsError ->
         {:noreply, put_flash(socket, :error, "无法加载对话或对话不存在。")}
      _ -> 
         {:noreply, put_flash(socket, :error, "选择对话时出错。")}
    end
  end

  # --- Helper Functions (Keep or adapt as needed) ---

  defp generate_ai_response(user_input) do
    # Keep this simple simulation for now
    cond do
      String.contains?(user_input, "你好") -> "你好！很高兴见到你！有什么我可以帮助你的？"
      String.contains?(user_input, "天气") -> "我没有实时的天气数据，但你可以查看本地气象网站获取最新天气信息。"
      String.contains?(user_input, "谢谢") -> "不客气！如果有其他问题，随时可以问我。"
      true -> "我理解你的问题是关于\"#{String.slice(user_input, 0, 30)}#{if String.length(user_input) > 30, do: "...", else: ""}\"。作为一个AI助手，我可以提供相关信息和帮助解决问题。请告诉我更多详细信息，这样我能更好地帮助你。"
    end
  end
  
  # This function might not be needed if using Ecto timestamps directly in the template
  defp format_time(datetime) when is_struct(datetime, NaiveDateTime) or is_struct(datetime, DateTime) do
    hour = datetime.hour |> Integer.to_string() |> String.pad_leading(2, "0")
    minute = datetime.minute |> Integer.to_string() |> String.pad_leading(2, "0")
    "#{hour}:#{minute}"
  end
  defp format_time(_), do: "--:--" # Fallback for invalid data
  
  # 根据当前侧边栏状态生成适当的类名
  # 在桌面端和移动端有不同的行为
  defp get_sidebar_classes(show) do
    desktop_class = if show, do: "sidebar", else: "sidebar hidden"
    mobile_class = if show, do: "sidebar show", else: "sidebar"
    "#{desktop_class} #{mobile_class}"
  end

end