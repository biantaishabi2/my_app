defmodule MyAppWeb.FormLive.Submit do
  use MyAppWeb, :live_view

  alias MyApp.Forms
  alias MyApp.Responses

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Forms.get_form_with_items(id) do
      nil ->
        {:ok, 
          socket
          |> put_flash(:error, "表单不存在")
          |> push_navigate(to: ~p"/forms")
        }
      
      form ->
        if form.status != :published do
          # 表单未发布，重定向到表单列表
          {:ok, 
            socket
            |> put_flash(:error, "表单未发布，无法填写")
            |> push_navigate(to: ~p"/forms")
          }
        else
          items_map = build_items_map(form.items)
          
          {:ok, 
            socket
            |> assign(:page_title, "填写表单 - #{form.title}")
            |> assign(:form, form)
            |> assign(:items_map, items_map)
            |> assign(:form_state, %{})
            |> assign(:errors, %{})
            |> assign(:submitted, false)
          }
        end
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", params, socket) do
    items_map = socket.assigns.items_map
    
    # 提取表单数据，简化为仅处理标准表单验证
    form_data = params["form"] || socket.assigns.form_state || %{}
    
    # 执行基本验证（必填项）
    errors = validate_form_data(form_data, items_map)
    
    {:noreply, 
      socket
      |> assign(:form_state, form_data)
      |> assign(:errors, errors)
    }
  end
  
  @impl true
  def handle_event("set_rating", %{"field-id" => field_id, "rating" => rating}, socket) do
    # 更新评分字段的值
    form_state = socket.assigns.form_state || %{}
    updated_form_state = Map.put(form_state, field_id, rating)
    
    # 重新验证
    errors = validate_form_data(updated_form_state, socket.assigns.items_map)
    
    {:noreply, 
      socket
      |> assign(:form_state, updated_form_state)
      |> assign(:errors, errors)
    }
  end

  # 不再需要单独的radio_change处理函数，由标准的validate函数处理所有字段

  @impl true
  def handle_event("submit_form", params, socket) do
    form_data = params["form"] || %{}
    form = socket.assigns.form
    items_map = socket.assigns.items_map
    
    # 执行验证
    errors = validate_form_data(form_data, items_map)
    
    if Enum.empty?(errors) do
      # 准备响应数据 - 不需要respondent_info，直接传递表单数据
      
      # 修正提交格式，直接传递表单数据而不是嵌套在answers中
      case Responses.create_response(form.id, form_data) do
        {:ok, _response} ->
          # 保持响应在此进程，以便测试可以查询它
          if :test == Mix.env() do
            Process.sleep(100) # 确保数据库事务完成
          end
          
          # 提交成功后，更新状态并重定向
          {:noreply, 
            socket
            |> assign(:submitted, true)
            |> put_flash(:info, "表单提交成功")
            |> push_navigate(to: ~p"/forms")
          }
          
        {:error, reason} ->
          {:noreply, 
            socket
            |> put_flash(:error, "表单提交失败: #{inspect(reason)}")
          }
      end
    else
      {:noreply, 
        socket
        |> assign(:form_state, form_data)
        |> assign(:errors, errors)
      }
    end
  end

  # 辅助函数

  # 构建表单项映射，以便于验证和显示
  defp build_items_map(items) do
    Enum.reduce(items, %{}, fn item, acc ->
      Map.put(acc, item.id, item)
    end)
  end

  # 验证表单数据
  defp validate_form_data(form_data, items_map) do
    Enum.reduce(items_map, %{}, fn {id, item}, errors ->
      # 获取对应项的值（可能是nil）
      value = Map.get(form_data || %{}, "#{id}", "")
      
      # 如果是必填项且值为空，则添加错误
      if item.required && (is_nil(value) || value == "") do
        Map.put(errors, id, "此字段为必填项")
      else
        errors
      end
    end)
  end
end