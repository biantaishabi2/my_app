defmodule MyAppWeb.PublicFormLive.SubmitTest do
  use MyAppWeb.ConnCase

  import Phoenix.LiveViewTest
  import MyApp.FormsFixtures
  import MyApp.AccountsFixtures
  
  alias MyApp.Forms
  alias MyApp.Responses

  @create_attrs %{title: "Public Form Submit Test", status: :draft}

  setup do
    user = user_fixture()
    {:ok, form} = Forms.create_form(Map.put(@create_attrs, :user_id, user.id))
    
    # 添加表单项
    {:ok, text_item} = Forms.add_form_item(form, %{
      type: :text_input,
      label: "Text Question",
      required: true,
      order: 1
    })

    {:ok, radio_item} = Forms.add_form_item(form, %{
      type: :radio,
      label: "Radio Question",
      required: true,
      order: 2
    })
    
    # 添加选项到单选按钮表单项
    {:ok, _option1} = Forms.add_item_option(radio_item, %{
      label: "Option 1",
      value: "opt1"
    })
    
    {:ok, _option2} = Forms.add_item_option(radio_item, %{
      label: "Option 2",
      value: "opt2"
    })
    
    # 发布表单
    {:ok, published_form} = Forms.publish_form(form)
    
    # 如果有分页相关功能，此处添加页面
    case Forms.list_form_pages(published_form.id) do
      [] ->
        # 创建默认页面
        {:ok, page} = Forms.create_form_page(published_form, %{
          title: "第一页",
          order: 1
        })
        
        # 将表单项分配到页面
        {:ok, _} = Forms.move_item_to_page(text_item.id, page.id)
        {:ok, _} = Forms.move_item_to_page(radio_item.id, page.id)
        
      _pages ->
        # 已有页面，不需要创建
        :ok
    end
    
    %{
      form: published_form,
      text_item: text_item,
      radio_item: radio_item
    }
  end

  describe "Public Form Submit" do
    test "displays the form submission page properly", %{conn: conn, form: form} do
      {:ok, view, html} = live(conn, ~p"/public/forms/#{form.id}/submit")
      
      # 验证页面标题
      assert html =~ form.title
      
      # 验证表单元素
      assert view |> has_element?("form")
      assert view |> has_element?(".respondent-info")
      assert view |> has_element?("input#respondent_name")
      assert view |> has_element?("input#respondent_email")
      assert view |> has_element?(".form-items")
      
      # 验证提交按钮
      assert view |> has_element?("button[type='submit']")
    end
    
    test "validates form submission", %{conn: conn, form: form, text_item: text_item, radio_item: radio_item} do
      {:ok, view, _html} = live(conn, ~p"/public/forms/#{form.id}/submit")
      
      # 提交空表单 - 应返回错误
      view
      |> form("#form-submit", %{
        "form_data" => %{},
        "respondent_info" => %{"name" => "", "email" => ""}
      })
      |> render_submit()
      
      # 验证错误信息显示
      assert view |> has_element?(".error-message")
      
      # 正确提交表单
      result = 
        view
        |> form("#form-submit", %{
          "form_data" => %{
            text_item.id => "Test Answer",
            radio_item.id => "opt1"
          },
          "respondent_info" => %{"name" => "Test User", "email" => "test@example.com"}
        })
        |> render_submit()
      
      # 检查是否重定向到成功页面 - 处理所有类型的重定向
      case result do
        {:error, {:redirect, %{to: path}}} ->
          assert path == "/public/forms/#{form.id}/success"
        {:error, {:live_redirect, %{to: path}}} ->
          assert path == "/public/forms/#{form.id}/success"
      end
      
      # 验证数据已保存到数据库
      [response] = Responses.list_responses_for_form(form.id)
      assert length(response.answers) == 2
      
      # 验证回答者信息已保存
      assert response.respondent_info["name"] == "Test User"
      assert response.respondent_info["email"] == "test@example.com"
    end
    
    test "redirects with error for non-existent forms", %{conn: conn} do
      # 使用有效的UUID格式但不存在的ID
      non_existent_id = Ecto.UUID.generate()
      result = live(conn, ~p"/public/forms/#{non_existent_id}/submit")
      assert {:error, {redirect_type, %{to: "/", flash: %{"error" => "表单不存在或未发布"}}}} = result
      assert redirect_type in [:redirect, :live_redirect]
    end
    
    test "redirects with error for draft forms", %{conn: conn, form: form} do
      # 重置为草稿状态
      {:ok, draft_form} = Forms.update_form(form, %{status: :draft})
      
      result = live(conn, ~p"/public/forms/#{draft_form.id}/submit")
      assert {:error, {redirect_type, %{to: "/", flash: %{"error" => "表单不存在或未发布"}}}} = result
      assert redirect_type in [:redirect, :live_redirect]
    end
  end
end