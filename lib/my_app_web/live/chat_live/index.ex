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
      show_sidebar: true,
      editing_conversation_id: nil, # 新增 - 当前正在编辑的对话ID
      deleting_conversation_id: nil  # 新增 - 当前正在删除的对话ID
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
                # 处理错误，设置闪烁消息并返回更新的socket
                socket = put_flash(socket, :error, "创建对话失败: #{inspect(changeset.errors)}")
                # 将更新的socket返回并在后续逻辑中使用
                socket
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
    
    # 如果正在编辑或删除，忽略选择事件
    if socket.assigns.editing_conversation_id != nil || socket.assigns.deleting_conversation_id != nil do
      {:noreply, socket}
    else
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
  end

  # 新增的事件处理函数 - 显示删除确认
  @impl true
  def handle_event("confirm_delete_conversation", %{"id" => id}, socket) do
    id_int = String.to_integer(id)
    IO.puts("确认删除对话: #{id_int}")
    {:noreply, assign(socket, deleting_conversation_id: id_int)}
  end

  # 新增的事件处理函数 - 取消删除
  @impl true
  def handle_event("cancel_delete", _params, socket) do
    IO.puts("取消删除对话")
    {:noreply, assign(socket, deleting_conversation_id: nil)}
  end

  # 新增的事件处理函数 - 执行删除
  @impl true
  def handle_event("delete_conversation", %{"id" => id_str}, socket) do
    current_user = socket.assigns.current_user
    id = String.to_integer(id_str)
    IO.puts("执行删除对话: #{id}")
    
    case Chat.delete_conversation(id, current_user) do
      {:ok, _} ->
        # 删除成功，更新对话列表
        IO.puts("删除成功")
        remaining_conversations = Enum.reject(socket.assigns.conversations, &(&1.id == id))
        
        # 如果删除的是当前对话，则切换到列表中的第一个对话
        {current_conversation, messages} =
          if socket.assigns.current_conversation && socket.assigns.current_conversation.id == id do
            case remaining_conversations do
              [] -> {nil, []}
              [first | _] ->
                conv = Chat.get_conversation_with_messages!(current_user, first.id)
                {conv, conv.messages}
            end
          else
            {socket.assigns.current_conversation, socket.assigns.messages}
          end
        
        {:noreply, socket
                 |> assign(:conversations, remaining_conversations)
                 |> assign(:current_conversation, current_conversation)
                 |> assign(:messages, messages)
                 |> assign(:deleting_conversation_id, nil)
                 |> put_flash(:info, "对话已删除")}
      
      {:error, reason} ->
        IO.puts("删除失败: #{inspect(reason)}")
        {:noreply, socket
                 |> assign(:deleting_conversation_id, nil)
                 |> put_flash(:error, "删除失败: #{inspect(reason)}")}
    end
  end

  # 新增的事件处理函数 - 显示编辑表单
  @impl true
  def handle_event("edit_conversation_name", %{"id" => id}, socket) do
    id_int = String.to_integer(id)
    IO.puts("编辑对话名称: #{id_int}")
    {:noreply, assign(socket, editing_conversation_id: id_int)}
  end

  # 新增的事件处理函数 - 处理键盘事件
  @impl true
  def handle_event("handle_edit_keydown", %{"key" => "Escape", "id" => _id}, socket) do
    IO.puts("按下Escape键取消编辑")
    {:noreply, assign(socket, editing_conversation_id: nil)}
  end
  
  # 处理回车键 - 保存编辑
  @impl true
  def handle_event("handle_edit_keydown", %{"key" => "Enter", "id" => _id}, socket) do
    IO.puts("按下Enter键保存编辑")
    # 获取当前表单中的值并提交
    # 注意：这里需要通过DOM查询获取当前值，但在LiveView中不直接操作DOM
    # 相反，我们应该依赖于表单的提交机制
    # 这个处理只是防止回车键的默认行为
    {:noreply, socket}
  end
  
  # 捕获其他键盘事件
  @impl true
  def handle_event("handle_edit_keydown", _params, socket) do
    {:noreply, socket}
  end

  # 新增的事件处理函数 - 保存编辑后的对话名称
  @impl true
  def handle_event("save_conversation_name", %{"id" => id_str, "title" => title}, socket) do
    current_user = socket.assigns.current_user
    id = String.to_integer(id_str)
    IO.puts("保存对话名称: #{id}, 标题: #{title}")
    
    # 如果标题为空，设置默认值
    title = if String.trim(title) == "", do: "新对话", else: String.trim(title)
    
    # 更新数据库中的对话标题
    case Chat.update_conversation_title(id, title, current_user) do
      {:ok, _updated_conversation} ->
        IO.puts("更新成功")
        # 更新对话列表
        updated_conversations = Enum.map(socket.assigns.conversations, fn conv ->
          if conv.id == id, do: %{conv | title: title}, else: conv
        end)
        
        # 如果当前选中的是被修改的对话，也需要更新当前对话
        current_conversation = 
          if socket.assigns.current_conversation && socket.assigns.current_conversation.id == id do
            %{socket.assigns.current_conversation | title: title}
          else
            socket.assigns.current_conversation
          end
        
        {:noreply, socket 
          |> assign(:conversations, updated_conversations)
          |> assign(:current_conversation, current_conversation)
          |> assign(:editing_conversation_id, nil)}
      
      {:error, reason} ->
        IO.puts("更新失败: #{inspect(reason)}")
        {:noreply, socket 
          |> put_flash(:error, "无法重命名对话") 
          |> assign(:editing_conversation_id, nil)}
    end
  end
  
  # 处理可能的参数格式问题 - 缺少id或title参数的情况
  @impl true
  def handle_event("save_conversation_name", params, socket) do
    IO.puts("保存对话名称: 参数格式不正确 #{inspect(params)}")
    # 从当前编辑状态中获取ID
    editing_id = socket.assigns.editing_conversation_id
    
    if editing_id && Map.has_key?(params, "title") do
      # 有title但是没有id，使用当前编辑的id
      handle_event("save_conversation_name", %{"id" => to_string(editing_id), "title" => params["title"]}, socket)
    else
      # 其他情况，取消编辑状态
      {:noreply, assign(socket, editing_conversation_id: nil)}
    end
  end

  # 新增的事件处理函数 - 点击输入框外部时取消编辑
  @impl true
  def handle_event("cancel_edit_name", _params, socket) do
    IO.puts("取消编辑对话名称")
    {:noreply, assign(socket, editing_conversation_id: nil)}
  end

  # 用于阻止事件冒泡的空函数
  @impl true
  def handle_event("void", _params, socket) do
    {:noreply, socket}
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