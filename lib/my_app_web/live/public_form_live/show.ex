defmodule MyAppWeb.PublicFormLive.Show do
  use MyAppWeb, :live_view

  alias MyApp.Forms
  alias MyApp.Forms.Form
  alias MyAppWeb.FormTemplateRenderer

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    # 获取表单（仅加载已发布的表单）
    case get_published_form(id) do
      {:ok, form} ->
        # 加载表单模板
        form_template = FormTemplateRenderer.load_form_template(form)
        
        # 初始化分页信息
        pages = form.pages || []
        current_page_idx = 0
        current_page = List.first(pages)
        
        # 获取当前页面的表单项
        page_items =
          if current_page do
            form.items
            |> Enum.filter(fn item -> item.page_id == current_page.id end)
            |> Enum.sort_by(& &1.order)
          else
            form.items |> Enum.sort_by(& &1.order)
          end
        
        # 初始化页面状态
        pages_status = initialize_pages_status(pages)
        
        socket =
          socket
          |> assign(:page_title, form.title)
          |> assign(:form, form)
          |> assign(:form_template, form_template)
          |> assign(:form_data, %{})
          |> assign(:errors, %{})
          |> assign(:jump_state, %{active: false, target_id: nil})
          |> assign(:current_page_idx, current_page_idx)
          |> assign(:current_page, current_page)
          |> assign(:page_items, page_items)
          |> assign(:pages_status, pages_status)
          |> assign(:total_pages, length(pages))

        {:ok, socket}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "表单不存在或未发布")
         |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :show, _params) do
    socket
    |> assign(:page_title, "查看表单 - #{socket.assigns.form.title}")
  end
  
  @impl true
  def handle_event("next_page", _params, socket) do
    current_idx = socket.assigns.current_page_idx
    total_pages = socket.assigns.total_pages
    form = socket.assigns.form
    
    if current_idx < total_pages - 1 do
      # 计算新页索引
      new_idx = current_idx + 1
      
      # 获取新页面
      new_page = Enum.at(form.pages, new_idx)
      
      # 获取当前页面的表单项
      page_items =
        form.items
        |> Enum.filter(fn item -> item.page_id == new_page.id end)
        |> Enum.sort_by(& &1.order)
      
      # 更新当前页面的状态为完成
      pages_status = update_page_status(socket.assigns.pages_status, current_idx, :complete)
      
      # 更新socket
      {:noreply, 
       socket
       |> assign(:current_page_idx, new_idx)
       |> assign(:current_page, new_page)
       |> assign(:page_items, page_items)
       |> assign(:pages_status, pages_status)}
    else
      # 已经是最后一页
      {:noreply, socket}
    end
  end
  
  @impl true
  def handle_event("prev_page", _params, socket) do
    current_idx = socket.assigns.current_page_idx
    form = socket.assigns.form
    
    if current_idx > 0 do
      # 计算新页索引
      new_idx = current_idx - 1
      
      # 获取新页面
      new_page = Enum.at(form.pages, new_idx)
      
      # 获取当前页面的表单项
      page_items =
        form.items
        |> Enum.filter(fn item -> item.page_id == new_page.id end)
        |> Enum.sort_by(& &1.order)
        
      # 更新socket
      {:noreply, 
       socket
       |> assign(:current_page_idx, new_idx)
       |> assign(:current_page, new_page)
       |> assign(:page_items, page_items)}
    else
      # 已经是第一页
      {:noreply, socket}
    end
  end
  
  @impl true
  def handle_event("jump_to_page", %{"index" => index_str}, socket) do
    form = socket.assigns.form
    pages = form.pages || []
    current_idx = socket.assigns.current_page_idx
    
    # 转换为整数
    {target_idx, _} = Integer.parse(index_str)
    
    # 确保索引在有效范围内
    valid_index = max(0, min(target_idx, length(pages) - 1))
    
    # 处理页面跳转
    target_page = Enum.at(pages, valid_index)
    
    # 获取目标页面的表单项
    page_items =
      form.items
      |> Enum.filter(fn item -> item.page_id == target_page.id end)
      |> Enum.sort_by(& &1.order)
    
    # 如果是向前跳转，将当前页面标记为已完成
    updated_status =
      if valid_index > current_idx do
        # 将当前页面标记为完成
        update_page_status(socket.assigns.pages_status, current_idx, :complete)
      else
        socket.assigns.pages_status
      end
    
    {:noreply,
     socket
     |> assign(:current_page_idx, valid_index)
     |> assign(:current_page, target_page)
     |> assign(:page_items, page_items)
     |> assign(:pages_status, updated_status)}
  end

  # 获取已发布的表单及其表单项和选项
  defp get_published_form(id) do
    case Forms.get_form(id) do
      nil ->
        {:error, :not_found}

      %Form{status: :published} = form ->
        # 预加载表单项和选项（已包含页面加载）
        form = Forms.preload_form_items_and_options(form)

        {:ok, form}

      %Form{} ->
        {:error, :not_found}
    end
  end
  
  # 初始化页面状态
  defp initialize_pages_status(pages) do
    pages
    |> Enum.with_index()
    |> Enum.map(fn {_page, idx} ->
      status = if idx == 0, do: :active, else: :pending
      {idx, status}
    end)
    |> Map.new()
  end

  # 更新页面状态
  defp update_page_status(pages_status, page_idx, new_status) do
    Map.put(pages_status, page_idx, new_status)
  end

end
