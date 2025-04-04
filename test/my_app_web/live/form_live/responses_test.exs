defmodule MyAppWeb.FormLive.ResponsesTest do
  use MyAppWeb.ConnCase

  import Phoenix.LiveViewTest
  import MyApp.FormsFixtures
  import MyApp.AccountsFixtures
  import MyApp.ResponsesFixtures

  alias MyApp.Forms
  alias MyApp.Responses

  setup :register_and_log_in_user

  describe "表单响应列表页面" do
    setup %{user: user} do
      # 创建一个测试表单和表单项
      form = form_fixture(%{user_id: user.id, title: "测试表单", description: "测试描述"})
      text_item = form_item_fixture(form, %{label: "文本问题", type: :text_input, required: true})
      radio_item = form_item_fixture(form, %{label: "单选问题", type: :radio, required: true})
      option1 = item_option_fixture(radio_item, %{label: "选项1", value: "option1"})
      option2 = item_option_fixture(radio_item, %{label: "选项2", value: "option2"})
      
      # 发布表单
      {:ok, published_form} = Forms.publish_form(form)
      
      # 创建三个测试响应
      response1 = response_fixture(published_form.id, %{
        "#{text_item.id}" => "回答1",
        "#{radio_item.id}" => "option1"
      })
      
      response2 = response_fixture(published_form.id, %{
        "#{text_item.id}" => "回答2",
        "#{radio_item.id}" => "option2"
      })
      
      response3 = response_fixture(published_form.id, %{
        "#{text_item.id}" => "回答3",
        "#{radio_item.id}" => "option1"
      })
      
      %{
        form: published_form, 
        text_item: text_item, 
        radio_item: radio_item,
        responses: [response1, response2, response3]
      }
    end

    test "访问表单响应列表页面", %{conn: conn, form: form} do
      {:ok, view, html} = live(conn, ~p"/forms/#{form.id}/responses")
      
      # 验证页面标题和表单信息
      assert html =~ "响应列表"
      assert html =~ form.title
      assert has_element?(view, "h1", "表单响应")
      assert has_element?(view, "h2", form.title)
    end

    test "显示响应列表", %{conn: conn, form: form, responses: responses} do
      {:ok, view, _html} = live(conn, ~p"/forms/#{form.id}/responses")
      
      # 验证显示正确数量的响应
      assert has_element?(view, "tr.response-row", count: 3)
      
      # 验证每个响应的信息都显示
      for response <- responses do
        assert has_element?(view, "td", response.id)
        # 检查提交时间显示格式
        submitted_at = response.submitted_at
        formatted_date = Calendar.strftime(submitted_at, "%Y-%m-%d %H:%M:%S")
        assert has_element?(view, "td", formatted_date)
      end
    end

    test "查看详细响应", %{conn: conn, form: form, responses: [response | _]} do
      {:ok, view, _html} = live(conn, ~p"/forms/#{form.id}/responses")
      
      # 点击查看详情链接
      {:ok, detail_view, detail_html} = 
        view
        |> element("a", "查看详情")
        |> render_click()
        |> follow_redirect(conn, ~p"/forms/#{form.id}/responses/#{response.id}")
      
      # 验证详情页面信息
      assert detail_html =~ "响应详情"
      assert detail_html =~ response.id
      assert has_element?(detail_view, "h1", "响应详情")
      
      # 验证显示了所有答案
      assert has_element?(detail_view, ".answer-item", count: 2)
    end

    test "删除响应", %{conn: conn, form: form, responses: [response | _]} do
      {:ok, view, _html} = live(conn, ~p"/forms/#{form.id}/responses")
      
      # 获取初始响应数量
      initial_count = Responses.list_responses_for_form(form.id) |> length()
      
      # 点击删除按钮
      view
      |> element("#delete-response-#{response.id}")
      |> render_click()
      
      # 确认删除对话框
      view
      |> element("button", "确认删除")
      |> render_click()
      
      # 验证响应已从页面移除
      refute has_element?(view, "#response-#{response.id}")
      
      # 验证数据库中响应已删除
      assert Responses.list_responses_for_form(form.id) |> length() == initial_count - 1
      assert Responses.get_response(response.id) == nil
    end

    test "其他用户不能查看响应", %{conn: conn} do
      # 创建另一个用户的表单和响应
      other_user = user_fixture()
      other_form = form_fixture(%{user_id: other_user.id, title: "其他用户的表单"})
      {:ok, published_form} = Forms.publish_form(other_form)
      
      # 尝试访问该表单的响应列表
      assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/forms/#{published_form.id}/responses")
      assert path =~ "/forms"
    end
  end

  describe "表单响应详情页面" do
    setup %{user: user} do
      # 创建一个测试表单和表单项
      form = form_fixture(%{user_id: user.id, title: "测试表单", description: "测试描述"})
      text_item = form_item_fixture(form, %{label: "文本问题", type: :text_input, required: true})
      radio_item = form_item_fixture(form, %{label: "单选问题", type: :radio, required: true})
      option1 = item_option_fixture(radio_item, %{label: "选项1", value: "option1"})
      option2 = item_option_fixture(radio_item, %{label: "选项2", value: "option2"})
      
      # 发布表单
      {:ok, published_form} = Forms.publish_form(form)
      
      # 创建一个测试响应
      response = response_fixture(published_form.id, %{
        "#{text_item.id}" => "这是一个文本回答",
        "#{radio_item.id}" => "option2"
      })
      
      %{
        form: published_form, 
        text_item: text_item, 
        radio_item: radio_item,
        response: response
      }
    end

    test "查看响应详情", %{conn: conn, form: form, response: response, text_item: text_item, radio_item: radio_item} do
      {:ok, view, html} = live(conn, ~p"/forms/#{form.id}/responses/#{response.id}")
      
      # 验证页面标题和响应信息
      assert html =~ "响应详情"
      assert html =~ response.id
      assert has_element?(view, "h1", "响应详情")
      
      # 验证提交时间显示
      submitted_at = response.submitted_at
      formatted_date = Calendar.strftime(submitted_at, "%Y-%m-%d %H:%M:%S")
      assert html =~ formatted_date
      
      # 验证显示了问题和答案
      assert has_element?(view, ".question", text_item.label)
      assert has_element?(view, ".answer", "这是一个文本回答")
      
      assert has_element?(view, ".question", radio_item.label)
      assert has_element?(view, ".answer", "选项2")
    end

    test "返回响应列表", %{conn: conn, form: form, response: response} do
      {:ok, view, _html} = live(conn, ~p"/forms/#{form.id}/responses/#{response.id}")
      
      # 点击返回按钮
      {:ok, list_view, _html} = 
        view
        |> element("a", "返回列表")
        |> render_click()
        |> follow_redirect(conn, ~p"/forms/#{form.id}/responses")
      
      # 验证返回到响应列表页面
      assert has_element?(list_view, "h1", "表单响应")
    end

    test "其他用户不能查看响应详情", %{conn: conn} do
      # 创建另一个用户的表单和响应
      other_user = user_fixture()
      other_form = form_fixture(%{user_id: other_user.id, title: "其他用户的表单"})
      {:ok, published_form} = Forms.publish_form(other_form)
      
      # 创建响应
      text_item = form_item_fixture(published_form, %{label: "问题", type: :text_input, required: true})
      response = response_fixture(published_form.id, %{"#{text_item.id}" => "回答"})
      
      # 尝试访问该响应的详情页面
      assert {:error, {:redirect, %{to: path}}} = 
        live(conn, ~p"/forms/#{published_form.id}/responses/#{response.id}")
      assert path =~ "/forms"
    end
  end
end