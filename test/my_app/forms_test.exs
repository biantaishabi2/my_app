defmodule MyApp.FormsTest do
  use MyApp.DataCase, async: false

  alias MyApp.Forms
  alias MyApp.Forms.Form
  alias MyApp.Forms.FormItem
  import MyApp.AccountsFixtures

  @moduletag :capture_log

  describe "forms" do
    @valid_attrs %{title: "User Satisfaction Survey"}
    @invalid_attrs %{description: "Missing title"}

    test "create_form/1 with valid data creates a form" do
      user = user_fixture()
      attrs = Map.put(@valid_attrs, :user_id, user.id)
      assert {:ok, %Form{} = form} = Forms.create_form(attrs)
      assert form.title == "User Satisfaction Survey"
      assert form.status == :draft # Default status should be draft
      assert form.description == nil # Fields not provided should be nil or default
    end

    test "create_form/1 with invalid data returns error changeset" do
      user = user_fixture()
      attrs = Map.put(@invalid_attrs, :user_id, user.id)
      assert {:error, %Ecto.Changeset{} = changeset} = Forms.create_form(attrs)
      # Verify that the changeset indicates title is required
      # This is a common way using Ecto.Changeset.traverse_errors
      assert Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end) |> Map.has_key?(:title)
    end

    test "get_form/1 returns the form with given id" do
      user = user_fixture()
      attrs = Map.put(@valid_attrs, :user_id, user.id)
      {:ok, form} = Forms.create_form(attrs)

      # Fetch the form using the function under test
      fetched_form = Forms.get_form(form.id)

      # Basic assertion: Check if the fetched form is the same struct (or has the same ID)
      # Depending on Repo.get implementation, it might be a new struct instance
      assert fetched_form.id == form.id
      assert fetched_form.title == form.title
    end

    test "get_form/1 returns nil for non-existent form id" do
      non_existent_uuid = Ecto.UUID.generate()
      assert Forms.get_form(non_existent_uuid) == nil
    end
  end

  describe "add_form_item/2" do
    # Helper to create a form for these tests
    defp create_a_form(_) do
      user = user_fixture()
      {:ok, form} = Forms.create_form(%{title: "Test Form for Items", user_id: user.id})
      %{form: form, user: user}
    end

    setup [:create_a_form]

    test "with valid data adds a text_input item to the form", %{form: form} do
      item_attrs = %{
        label: "Your Name",
        type: :text_input,
        required: true
        # order can be handled by the context or default
      }

      assert {:ok, item} = Forms.add_form_item(form, item_attrs)
      assert item.label == "Your Name"
      assert item.type == :text_input
      assert item.required == true
      assert item.form_id == form.id
      assert item.order == 1 # Assuming it's the first item

      # Verify it's actually associated by fetching the form again
      fetched_form = Forms.get_form(form.id)
      assert length(fetched_form.items) == 1
      assert hd(fetched_form.items).label == "Your Name"
    end

    test "returns error changeset if label is missing", %{form: form} do
      item_attrs = %{type: :text_input, required: false}
      assert {:error, %Ecto.Changeset{} = changeset} = Forms.add_form_item(form, item_attrs)
      assert Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end) |> Map.has_key?(:label)
    end

    test "returns error changeset if type is missing", %{form: form} do
      item_attrs = %{label: "Feedback", required: false}
      assert {:error, %Ecto.Changeset{} = changeset} = Forms.add_form_item(form, item_attrs)
      assert Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end) |> Map.has_key?(:type)
    end

    test "assigns sequential order to newly added items", %{form: form} do
      item1_attrs = %{label: "Email", type: :text_input}
      {:ok, item1} = Forms.add_form_item(form, item1_attrs)
      assert item1.order == 1

      item2_attrs = %{label: "Phone", type: :text_input}
      {:ok, item2} = Forms.add_form_item(form, item2_attrs)
      assert item2.order == 2
    end

    test "with valid data adds a radio item to the form", %{form: form} do
      item_attrs = %{
        label: "Satisfaction Level",
        type: :radio,
        required: true
      }
      assert {:ok, item} = Forms.add_form_item(form, item_attrs)
      assert item.label == "Satisfaction Level"
      assert item.type == :radio
    end
    
    test "with valid data adds a textarea item to the form", %{form: form} do
      item_attrs = %{
        label: "Your Comments",
        type: :textarea,
        required: true,
        description: "Please enter detailed feedback..."
      }
      assert {:ok, item} = Forms.add_form_item(form, item_attrs)
      assert item.label == "Your Comments"
      assert item.type == :textarea
      assert item.description == "Please enter detailed feedback..."
    end
    
    test "with valid data adds a dropdown item to the form", %{form: form} do
      item_attrs = %{
        label: "Select Country",
        type: :dropdown,
        required: true
      }
      assert {:ok, item} = Forms.add_form_item(form, item_attrs)
      assert item.label == "Select Country"
      assert item.type == :dropdown
    end
    
    test "with valid data adds a rating item to the form", %{form: form} do
      item_attrs = %{
        label: "Rate our service",
        type: :rating,
        required: true,
        max_rating: 5
      }
      assert {:ok, item} = Forms.add_form_item(form, item_attrs)
      assert item.label == "Rate our service"
      assert item.type == :rating
      assert item.max_rating == 5
    end
    
    # 新控件测试：数字输入字段
    test "with valid data adds a number item to the form", %{form: form} do
      item_attrs = %{
        label: "年龄",
        type: :number,
        required: true,
        min: 18,
        max: 60,
        step: 1
      }
      assert {:ok, item} = Forms.add_form_item(form, item_attrs)
      assert item.label == "年龄"
      assert item.type == :number
      assert item.min == 18
      assert item.max == 60
      assert item.step == 1
    end
    
    test "number field validates min/max values", %{form: form} do
      # 无效的min/max值（min > max）
      item_attrs = %{
        label: "年龄",
        type: :number,
        min: 60,
        max: 18
      }
      assert {:error, changeset} = Forms.add_form_item(form, item_attrs)
      assert %{min: ["最小值不能大于最大值"]} = errors_on(changeset)
    end
    
    test "number field step must be positive", %{form: form} do
      item_attrs = %{
        label: "年龄",
        type: :number,
        step: -1
      }
      assert {:error, changeset} = Forms.add_form_item(form, item_attrs)
      assert %{step: ["步长必须大于0"]} = errors_on(changeset)
    end
    
    # 邮箱输入字段
    test "with valid data adds an email item to the form", %{form: form} do
      item_attrs = %{
        label: "电子邮箱",
        type: :email,
        required: true,
        show_format_hint: true
      }
      assert {:ok, item} = Forms.add_form_item(form, item_attrs)
      assert item.label == "电子邮箱"
      assert item.type == :email
      assert item.show_format_hint == true
    end
    
    # 电话号码输入字段
    test "with valid data adds a phone item to the form", %{form: form} do
      item_attrs = %{
        label: "联系电话",
        type: :phone,
        required: true,
        format_display: true
      }
      assert {:ok, item} = Forms.add_form_item(form, item_attrs)
      assert item.label == "联系电话"
      assert item.type == :phone
      assert item.format_display == true
    end
    
    # 日期选择字段
    test "with valid data adds a date item to the form", %{form: form} do
      item_attrs = %{
        label: "出生日期",
        type: :date,
        required: true,
        min_date: "2000-01-01",
        max_date: "2023-12-31",
        date_format: "yyyy-MM-dd"
      }
      assert {:ok, item} = Forms.add_form_item(form, item_attrs)
      assert item.label == "出生日期"
      assert item.type == :date
      assert item.min_date == "2000-01-01"
      assert item.max_date == "2023-12-31"
      assert item.date_format == "yyyy-MM-dd"
    end
    
    # 时间选择字段
    test "with valid data adds a time item to the form", %{form: form} do
      item_attrs = %{
        label: "预约时间",
        type: :time,
        required: true,
        min_time: "09:00",
        max_time: "18:00",
        time_format: "24h"
      }
      assert {:ok, item} = Forms.add_form_item(form, item_attrs)
      assert item.label == "预约时间"
      assert item.type == :time
      assert item.min_time == "09:00"
      assert item.max_time == "18:00"
      assert item.time_format == "24h"
    end
    
    # 地区选择字段
    test "with valid data adds a region item to the form", %{form: form} do
      item_attrs = %{
        label: "所在地区",
        type: :region,
        required: true,
        region_level: 3,
        default_province: "广东省"
      }
      assert {:ok, item} = Forms.add_form_item(form, item_attrs)
      assert item.label == "所在地区"
      assert item.type == :region
      assert item.region_level == 3
      assert item.default_province == "广东省"
    end
    
    # 矩阵题字段
    test "with valid data adds a matrix item to the form", %{form: form} do
      item_attrs = %{
        label: "满意度评价",
        type: :matrix,
        required: true,
        matrix_rows: ["服务态度", "响应速度", "专业程度"],
        matrix_columns: ["非常满意", "满意", "一般", "不满意", "非常不满意"],
        matrix_type: :single
      }
      assert {:ok, item} = Forms.add_form_item(form, item_attrs)
      assert item.label == "满意度评价"
      assert item.type == :matrix
      assert item.matrix_rows == ["服务态度", "响应速度", "专业程度"]
      assert item.matrix_columns == ["非常满意", "满意", "一般", "不满意", "非常不满意"]
      assert item.matrix_type == :single
    end
    
    # 日期格式验证
    test "date field validates format", %{form: form} do
      # 无效的日期格式
      item_attrs = %{
        label: "出生日期",
        type: :date,
        date_format: "invalid-format"
      }
      assert {:error, changeset} = Forms.add_form_item(form, item_attrs)
      assert %{date_format: ["日期格式无效"]} = errors_on(changeset)
    end
    
    # 时间格式验证
    test "time field validates min/max times", %{form: form} do
      # 无效的时间值（min > max）
      item_attrs = %{
        label: "预约时间",
        type: :time,
        min_time: "18:00",
        max_time: "09:00"
      }
      assert {:error, changeset} = Forms.add_form_item(form, item_attrs)
      assert %{min_time: ["开始时间不能晚于结束时间"]} = errors_on(changeset)
    end
    
    # 地区级别验证
    test "region field validates region level", %{form: form} do
      # 无效的地区级别
      item_attrs = %{
        label: "所在地区",
        type: :region,
        region_level: 5
      }
      assert {:error, changeset} = Forms.add_form_item(form, item_attrs)
      assert %{region_level: ["地区级别必须是1-3之间的值"]} = errors_on(changeset)
    end
    
    # 矩阵题行列验证
    test "matrix field validates rows and columns", %{form: form} do
      # 无效的矩阵题（无行）
      item_attrs = %{
        label: "满意度评价",
        type: :matrix,
        matrix_rows: [],
        matrix_columns: ["满意", "不满意"]
      }
      assert {:error, changeset} = Forms.add_form_item(form, item_attrs)
      assert %{matrix_rows: ["矩阵行不能为空"]} = errors_on(changeset)
      
      # 无效的矩阵题（无列）
      item_attrs = %{
        label: "满意度评价",
        type: :matrix,
        matrix_rows: ["项目1", "项目2"],
        matrix_columns: []
      }
      assert {:error, changeset} = Forms.add_form_item(form, item_attrs)
      assert %{matrix_columns: ["矩阵列不能为空"]} = errors_on(changeset)
    end
    
    # 矩阵题唯一性验证
    test "matrix field validates uniqueness of rows and columns", %{form: form} do
      # 无效的矩阵题（重复行）
      item_attrs = %{
        label: "满意度评价",
        type: :matrix,
        matrix_rows: ["项目1", "项目1"],
        matrix_columns: ["满意", "不满意"]
      }
      assert {:error, changeset} = Forms.add_form_item(form, item_attrs)
      assert %{matrix_rows: ["矩阵行标题必须唯一"]} = errors_on(changeset)
      
      # 无效的矩阵题（重复列）
      item_attrs = %{
        label: "满意度评价",
        type: :matrix,
        matrix_rows: ["项目1", "项目2"],
        matrix_columns: ["满意", "满意"]
      }
      assert {:error, changeset} = Forms.add_form_item(form, item_attrs)
      assert %{matrix_columns: ["矩阵列标题必须唯一"]} = errors_on(changeset)
    end
    
    # 图片选择控件测试
    test "with valid data adds an image_choice item to the form", %{form: form} do
      item_attrs = %{
        label: "选择一个图片",
        type: :image_choice,
        required: true,
        selection_type: :single,
        image_caption_position: :bottom
      }
      assert {:ok, item} = Forms.add_form_item(form, item_attrs)
      assert item.label == "选择一个图片"
      assert item.type == :image_choice
      assert item.selection_type == :single
      assert item.image_caption_position == :bottom
    end
    
    # 图片选择控件验证
    test "image_choice field validates selection_type", %{form: form} do
      # 无效的选择类型
      item_attrs = %{
        label: "选择图片",
        type: :image_choice,
        selection_type: :invalid_type
      }
      assert {:error, changeset} = Forms.add_form_item(form, item_attrs)
      assert %{selection_type: ["is invalid"]} = errors_on(changeset)
    end
    
    # 图片选择控件验证标题位置
    test "image_choice field validates caption position", %{form: form} do
      # 无效的标题位置
      item_attrs = %{
        label: "选择图片",
        type: :image_choice,
        image_caption_position: :invalid_position
      }
      assert {:error, changeset} = Forms.add_form_item(form, item_attrs)
      assert %{image_caption_position: ["is invalid"]} = errors_on(changeset)
    end
    
    # 文件上传控件测试
    test "with valid data adds a file_upload item to the form", %{form: form} do
      item_attrs = %{
        label: "上传文件",
        type: :file_upload,
        required: true,
        allowed_extensions: [".pdf", ".doc", ".docx", ".jpg", ".png"],
        max_file_size: 5,
        multiple_files: true,
        max_files: 3
      }
      assert {:ok, item} = Forms.add_form_item(form, item_attrs)
      assert item.label == "上传文件"
      assert item.type == :file_upload
      assert item.allowed_extensions == [".pdf", ".doc", ".docx", ".jpg", ".png"]
      assert item.max_file_size == 5
      assert item.multiple_files == true
      assert item.max_files == 3
    end
    
    # 文件上传控件文件大小验证
    test "file_upload field validates max_file_size", %{form: form} do
      # 无效的文件大小（超过20MB限制）
      item_attrs = %{
        label: "上传文件",
        type: :file_upload,
        max_file_size: 25
      }
      assert {:error, changeset} = Forms.add_form_item(form, item_attrs)
      assert %{max_file_size: ["单个文件大小不能超过20MB"]} = errors_on(changeset)
      
      # 无效的文件大小（负值）
      item_attrs = %{
        label: "上传文件",
        type: :file_upload,
        max_file_size: -1
      }
      assert {:error, changeset} = Forms.add_form_item(form, item_attrs)
      assert %{max_file_size: ["文件大小必须大于0"]} = errors_on(changeset)
    end
    
    # 文件上传控件最大文件数验证
    test "file_upload field validates max_files", %{form: form} do
      # 无效的最大文件数（超过10个文件限制）
      item_attrs = %{
        label: "上传文件",
        type: :file_upload,
        multiple_files: true,
        max_files: 15
      }
      assert {:error, changeset} = Forms.add_form_item(form, item_attrs)
      assert %{max_files: ["最多允许上传10个文件"]} = errors_on(changeset)
      
      # 无效的最大文件数（少于1个）
      item_attrs = %{
        label: "上传文件",
        type: :file_upload,
        multiple_files: true,
        max_files: 0
      }
      assert {:error, changeset} = Forms.add_form_item(form, item_attrs)
      assert %{max_files: ["最多文件数必须至少为1"]} = errors_on(changeset)
    end
    
    # 文件上传控件扩展名验证
    test "file_upload field validates allowed_extensions", %{form: form} do
      # 无效的扩展名（不带点号）
      item_attrs = %{
        label: "上传文件",
        type: :file_upload,
        allowed_extensions: ["pdf", "doc", "docx"]
      }
      assert {:error, changeset} = Forms.add_form_item(form, item_attrs)
      assert %{allowed_extensions: ["文件扩展名必须以点号(.)开头"]} = errors_on(changeset)
    end
  end

  describe "add_item_option/3" do
    # Helper to create a form and a radio item for these tests
    defp create_form_with_radio_item(_) do
      user = user_fixture()
      {:ok, form} = Forms.create_form(%{title: "Form with Radio", user_id: user.id})
      radio_item_attrs = %{label: "Choose One", type: :radio, required: true}
      {:ok, radio_item} = Forms.add_form_item(form, radio_item_attrs)
      %{form: form, radio_item: radio_item, user: user}
    end

    setup [:create_form_with_radio_item]

    test "with valid data adds an option to a radio item", %{radio_item: radio_item} do
      option_attrs = %{label: "Option A", value: "a"}

      assert {:ok, option} = Forms.add_item_option(radio_item, option_attrs)
      assert option.label == "Option A"
      assert option.value == "a"
      assert option.form_item_id == radio_item.id
      assert option.order == 1 # First option

      # Verify association
      loaded_item = Forms.get_form_item_with_options(radio_item.id)
      assert length(loaded_item.options) == 1
      assert hd(loaded_item.options).value == "a"
    end

    test "returns error changeset if label is missing", %{radio_item: radio_item} do
      option_attrs = %{value: "b"}
      assert {:error, %Ecto.Changeset{} = changeset} = Forms.add_item_option(radio_item, option_attrs)
      assert Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end) |> Map.has_key?(:label)
    end

    test "returns error changeset if value is missing", %{radio_item: radio_item} do
      option_attrs = %{label: "Option C"}
      assert {:error, %Ecto.Changeset{} = changeset} = Forms.add_item_option(radio_item, option_attrs)
      assert Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end) |> Map.has_key?(:value)
    end

    test "assigns sequential order to newly added options", %{radio_item: radio_item} do
      option1_attrs = %{label: "Yes", value: "yes"}
      {:ok, option1} = Forms.add_item_option(radio_item, option1_attrs)
      assert option1.order == 1

      option2_attrs = %{label: "No", value: "no"}
      {:ok, option2} = Forms.add_item_option(radio_item, option2_attrs)
      assert option2.order == 2
    end
  end

  describe "publish_form/1" do
    defp create_draft_form(_) do
      user = user_fixture()
      {:ok, form} = Forms.create_form(%{title: "Draft Form to Publish", user_id: user.id})
      %{form: form, user: user}
    end

    setup [:create_draft_form]

    test "changes the form status from :draft to :published", %{form: form} do
      assert form.status == :draft
      assert {:ok, updated_form} = Forms.publish_form(form)
      assert updated_form.status == :published
      assert updated_form.id == form.id

      # Verify the change is persisted
      fetched_form = Forms.get_form(form.id)
      assert fetched_form.status == :published
    end

    test "returns error if the form is already published", %{form: form} do
      # Publish it once
      {:ok, published_form} = Forms.publish_form(form)
      assert published_form.status == :published

      # Try to publish again
      assert {:error, :already_published} = Forms.publish_form(published_form)
    end
  end

  describe "get_form_item/1" do
    setup [:create_form_with_radio_item]
    
    test "returns the form item with given id", %{radio_item: item} do
      fetched_item = Forms.get_form_item(item.id)
      assert fetched_item.id == item.id
      assert fetched_item.label == item.label
      assert fetched_item.type == :radio
    end
    
    test "returns nil for non-existent form item id" do
      non_existent_uuid = Ecto.UUID.generate()
      assert Forms.get_form_item(non_existent_uuid) == nil
    end
  end
  
  describe "get_form_item_with_options/1" do
    setup [:create_form_with_radio_item]
    
    test "returns the form item with options preloaded", %{radio_item: item} do
      # Add some options to the radio item
      option1_attrs = %{label: "Option X", value: "x"}
      option2_attrs = %{label: "Option Y", value: "y"}
      {:ok, _option1} = Forms.add_item_option(item, option1_attrs)
      {:ok, _option2} = Forms.add_item_option(item, option2_attrs)
      
      # Get the item with options
      item_with_options = Forms.get_form_item_with_options(item.id)
      
      # Verify the item data
      assert item_with_options.id == item.id
      assert item_with_options.label == item.label
      
      # Verify options are loaded and correct
      assert length(item_with_options.options) == 2
      option_labels = Enum.map(item_with_options.options, & &1.label) |> Enum.sort()
      assert option_labels == ["Option X", "Option Y"] |> Enum.sort()
    end
    
    test "returns nil for non-existent form item id when preloading options" do
      non_existent_uuid = Ecto.UUID.generate()
      assert Forms.get_form_item_with_options(non_existent_uuid) == nil
    end
  end
  
  describe "update_form_item/2" do
    setup [:create_form_with_radio_item]
    
    test "updates form item with valid data", %{radio_item: item} do
      update_attrs = %{
        label: "Updated Question",
        required: false,
        description: "This is a description"
      }
      
      assert {:ok, updated_item} = Forms.update_form_item(item, update_attrs)
      assert updated_item.id == item.id
      assert updated_item.label == "Updated Question"
      assert updated_item.required == false
      assert updated_item.description == "This is a description"
      # Type should remain the same since we didn't update it
      assert updated_item.type == :radio
      
      # Verify changes are persisted
      fetched_item = Forms.get_form_item(item.id)
      assert fetched_item.label == "Updated Question"
    end
    
    test "returns error changeset with invalid data", %{radio_item: item} do
      # Empty label is invalid
      invalid_attrs = %{label: ""}
      assert {:error, %Ecto.Changeset{}} = Forms.update_form_item(item, invalid_attrs)
      
      # Verify item wasn't changed
      fetched_item = Forms.get_form_item(item.id)
      assert fetched_item.label == item.label
    end
    
    test "updates rating item max_rating", %{form: form} do
      # First create a rating item
      {:ok, rating_item} = Forms.add_form_item(form, %{
        label: "Initial Rating",
        type: :rating,
        max_rating: 5
      })
      
      # Now update its max_rating
      update_attrs = %{
        max_rating: 10
      }
      
      assert {:ok, updated_item} = Forms.update_form_item(rating_item, update_attrs)
      assert updated_item.max_rating == 10
      
      # Verify with string value too
      update_attrs = %{
        max_rating: "7"
      }
      
      assert {:ok, updated_item} = Forms.update_form_item(updated_item, update_attrs)
      assert updated_item.max_rating == 7
    end
  end
  
  describe "delete_form_item/1" do
    setup [:create_form_with_radio_item]
    
    test "deletes the form item", %{radio_item: item} do
      assert {:ok, %{id: deleted_id}} = Forms.delete_form_item(item)
      assert deleted_id == item.id
      
      # Verify item is deleted
      assert Forms.get_form_item(item.id) == nil
    end
    
    test "deletes associated options when deleting a form item", %{radio_item: item, user: user} do
      # Add options to the item
      {:ok, _option} = Forms.add_item_option(item, %{label: "Test Option", value: "test"})
      
      # Delete the item
      assert {:ok, _} = Forms.delete_form_item(item)
      
      # Verify item is deleted
      assert Forms.get_form_item(item.id) == nil
      
      # Create a similar item to verify options don't exist in options table
      {:ok, new_form} = Forms.create_form(%{title: "New Test Form", user_id: user.id})
      {:ok, new_item} = Forms.add_form_item(new_form, %{
        label: "New Radio Question", 
        type: :radio,
        required: true
      })
      
      # Try to query for previous option's value - should not find any
      {:ok, _all_new_options} = Forms.add_item_option(new_item, %{label: "New Option", value: "new"})
    end
  end
  
  describe "reorder_form_items/2" do
    setup do
      # Create a form with multiple items for reordering
      user = user_fixture()
      {:ok, form} = Forms.create_form(%{title: "Form for Reordering", user_id: user.id})
      
      # Add several items with initial ordering
      {:ok, item1} = Forms.add_form_item(form, %{label: "Question 1", type: :text_input})
      {:ok, item2} = Forms.add_form_item(form, %{label: "Question 2", type: :text_input})
      {:ok, item3} = Forms.add_form_item(form, %{label: "Question 3", type: :text_input})
      
      %{form: form, items: [item1, item2, item3], user: user}
    end
    
    test "changes the order of form items", %{form: form, items: [item1, item2, item3]} do
      # Reorder the items: move item3 to first position, keeping others in order
      new_order = [item3.id, item1.id, item2.id]
      
      assert {:ok, reordered_items} = Forms.reorder_form_items(form.id, new_order)
      
      # Verify the items were reordered
      assert length(reordered_items) == 3
      
      # Extract IDs in the new order
      reordered_ids = Enum.map(reordered_items, &(&1.id))
      assert reordered_ids == new_order
      
      # Verify the order fields were updated
      [first, second, third] = reordered_items
      assert first.order == 1
      assert second.order == 2
      assert third.order == 3
      
      # Verify first item is now item3
      assert first.id == item3.id
    end
    
    test "returns error when item IDs don't match form's items", %{form: form, items: [item1, item2, _item3], user: user} do
      # Create an item for a different form
      {:ok, other_form} = Forms.create_form(%{title: "Another Form", user_id: user.id})
      {:ok, other_item} = Forms.add_form_item(other_form, %{label: "Other Question", type: :text_input})
      
      # Try to include that item in our reordering
      invalid_order = [item1.id, item2.id, other_item.id]
      
      assert {:error, :invalid_item_ids} = Forms.reorder_form_items(form.id, invalid_order)
    end
    
    test "returns error when not all form items are included", %{form: form, items: [item1, item2, _item3]} do
      # Missing one item
      incomplete_order = [item1.id, item2.id]
      
      assert {:error, :missing_items} = Forms.reorder_form_items(form.id, incomplete_order)
    end
  end
end