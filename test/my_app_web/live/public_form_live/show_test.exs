defmodule MyAppWeb.PublicFormLive.ShowTest do
  use MyAppWeb.ConnCase

  import Phoenix.LiveViewTest
  import MyApp.FormsFixtures
  import MyApp.AccountsFixtures

  alias MyApp.Forms

  @create_attrs %{title: "public form test", status: :draft}

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
    
    %{
      form: published_form,
      text_item: text_item,
      radio_item: radio_item
    }
  end

  describe "Public Form Show" do
    test "displays published form details properly", %{conn: conn, form: form} do
      {:ok, view, html} = live(conn, ~p"/public/forms/#{form.id}")
      
      # 验证页面标题
      assert html =~ form.title
      
      # 验证表单项显示
      assert view |> has_element?(".public-form-header")
      assert view |> has_element?(".public-form-content")
      assert view |> has_element?(".public-form-items")
      
      # 验证填写表单按钮
      assert view |> has_element?("a", "填写此表单")
    end
    
    test "redirects with error for non-existent forms", %{conn: conn} do
      # 使用有效的UUID格式但不存在的ID
      non_existent_id = Ecto.UUID.generate()
      result = live(conn, ~p"/public/forms/#{non_existent_id}")
      assert {:error, {redirect_type, %{to: "/", flash: %{"error" => "表单不存在或未发布"}}}} = result
      assert redirect_type in [:redirect, :live_redirect]
    end
    
    test "redirects with error for draft forms", %{conn: conn, form: form} do
      # 重置为草稿状态
      {:ok, draft_form} = Forms.update_form(form, %{status: :draft})
      
      result = live(conn, ~p"/public/forms/#{draft_form.id}")
      assert {:error, {redirect_type, %{to: "/", flash: %{"error" => "表单不存在或未发布"}}}} = result
      assert redirect_type in [:redirect, :live_redirect]
    end
  end
end