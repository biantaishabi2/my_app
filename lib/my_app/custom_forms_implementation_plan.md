# 自定义表单系统 - 实施计划

**目标:** 逐个实现缺失的功能，让 `test/my_app/forms_test.exs` 和 `test/my_app/responses_test.exs` 中的测试通过。

**遵循 TDD 流程：针对一个失败的测试 -> 编写最少代码让它通过 -> (可选) 重构 -> 运行所有相关测试 -> 重复。**

---

## 阶段一：实现核心 `Form` 模块功能

1.  **数据库基础 (Forms 相关)**
    *   [x] **生成迁移文件**: 运行 `mix ecto.gen.migration create_forms_tables` (或类似，包含 forms, form_items, item_options)。
    *   [x] **编写迁移**: 在迁移文件中定义 `forms`, `form_items`, `item_options` 表的结构，包括字段、类型、约束 (非空、外键)、索引，确保主键为 `binary_id`。
    *   [x] **运行迁移**: 运行 `mix ecto.migrate` 创建数据库表。

2.  **实现 `MyApp.Forms.create_form/1`**
    *   [x] 在 `lib/my_app/forms.ex` 中定义 `create_form/1` 函数。
    *   [x] 引入 `Repo` 和 `MyApp.Forms.Form` 别名。
    *   [x] 使用 `Form.changeset/2` 处理 `attrs`。
    *   [x] 使用 `Repo.insert/1` 保存表单。
    *   [x] **运行测试**: `mix test test/my_app/forms_test.exs:14` (create_form valid) 和 `test/my_app/forms_test.exs:21` (create_form invalid)。

3.  **实现 `MyApp.Forms.get_form/1`**
    *   [x] 在 `lib/my_app/forms.ex` 中定义 `get_form/1` 函数。
    *   [x] 使用 `Repo.get/2` 通过 ID 获取表单。
    *   [ ] **(注意)** 如果需要预加载关联数据 (如 `items`)，后续在此处添加 `Repo.preload/2`。
    *   [x] **运行测试**: `mix test test/my_app/forms_test.exs:29` (get_form valid) 和 `test/my_app/forms_test.exs:45` (get_form non-existent)。

4.  **实现 `MyApp.Forms.add_form_item/2`**
    *   [x] 在 `lib/my_app/forms.ex` 中定义 `add_form_item/2` 函数 (接收 `form` struct 和 `item_attrs`)。
    *   [x] 引入 `MyApp.Forms.FormItem` 别名。
    *   [x] **计算 `order`**: 查询当前表单下已有 `items` 的数量，新 `order` 为 `count + 1`。
    *   [x] 构造 `item_attrs`，包含计算好的 `order` 和 `form_id`。
    *   [x] 使用 `FormItem.changeset/2` 处理 `item_attrs`。
    *   [x] 使用 `Repo.insert/1` 保存表单项。
    *   [x] **运行测试**: 涉及 `add_form_item` 的测试，如 `test/my_app/forms_test.exs:60` (add text_input), `test/my_app/forms_test.exs:105` (add radio), `test/my_app/forms_test.exs:83` (missing label), `test/my_app/forms_test.exs:89` (missing type), `test/my_app/forms_test.exs:95` (order)。

5.  **实现 `MyApp.Forms.add_item_option/2`**
    *   [x] 在 `lib/my_app/forms.ex` 中定义 `add_item_option/2` 函数 (接收 `form_item` struct 和 `option_attrs`)。
    *   [x] 引入 `MyApp.Forms.ItemOption` 别名。
    *   [x] **计算 `order`**: 查询当前 `form_item` 下已有 `options` 的数量，新 `order` 为 `count + 1`。
    *   [x] 构造 `option_attrs`，包含计算好的 `order` 和 `form_item_id`。
    *   [x] 使用 `ItemOption.changeset/2` 处理 `option_attrs`。
    *   [x] 使用 `Repo.insert/1` 保存选项。
    *   [x] **运行测试**: 涉及 `add_item_option` 的测试，如 `test/my_app/forms_test.exs:128` (add option), `test/my_app/forms_test.exs:143` (missing label), `test/my_app/forms_test.exs:149` (missing value), `test/my_app/forms_test.exs:155` (order)。

6.  **实现 `MyApp.Forms.publish_form/1`**
    *   [x] 在 `lib/my_app/forms.ex` 中定义 `publish_form/1` 函数。
    *   [x] 检查传入表单的当前 `status`。如果不是 `:draft`，返回错误（如 `{:error, :already_published}` 或 `{:error, :invalid_status}`）。
    *   [x] 如果是 `:draft`，使用 `Form.changeset/2` (或创建专用 changeset) 将 `status` 更新为 `:published`。
    *   [x] 使用 `Repo.update/1` 更新表单。
    *   [x] **运行测试**: `test/my_app/forms_test.exs:183` (publish draft), `test/my_app/forms_test.exs:194` (re-publish published)。

---

## 阶段二：实现核心 `Response` 模块功能

7.  **数据库基础 (Responses 相关)**
    *   [x] **生成迁移文件**: 运行 `mix ecto.gen.migration create_responses_tables` (或类似，包含 responses, answers)。
    *   [x] **编写迁移**: 在迁移文件中定义 `responses`, `answers` 表的结构，包括字段 (`submitted_at`, `respondent_info`, `value` - 推荐 `map` 或 `jsonb`)、类型、约束、索引、外键。
    *   [x] **运行迁移**: 运行 `mix ecto.migrate` 创建数据库表。

8.  **实现 `MyApp.Responses.create_response/2`**
    *   [x] 在 `lib/my_app/responses.ex` 中定义 `create_response/2` 函数 (接收 `form_id` 和 `answers_map`)。
    *   [x] 引入 `Repo`, `MyApp.Responses.Response`, `MyApp.Responses.Answer`, `MyApp.Forms` 别名。
    *   [x] **获取并验证表单**: 使用 `Forms.get_form/1` 获取 `form_id` 对应的表单，并预加载 `items` 及其 `options` (`Repo.preload(form, [items: :options])`)。验证表单是否存在且状态为 `:published`。
    *   [x] **验证答案**: 
        *   遍历表单的 `items`。
        *   检查必填项 (`required: true`) 是否在 `answers_map` 中存在答案。
        *   对于 `:radio` (及后续 `:dropdown`) 类型，验证 `answers_map` 中的值是否是该 `item` 的有效 `option.value` 之一。
        *   (后续可添加其他验证，如 `:text_input` 格式)。
        *   如果验证失败，返回 `{:error, reason}` (例如 `{:error, :validation_failed}` 或 `{:error, :invalid_answer, item_id}`）。
    *   [x] **构建数据**: 如果验证通过，创建 `Response` 结构 (设置 `submitted_at`, `form_id`) 和 `Answer` 结构列表 (设置 `value`, `form_item_id`)。
    *   [x] **原子化插入**: 使用 `Repo.transaction/1`，将 `Response` 和所有 `Answers` 一起插入数据库。
    *   [x] **运行测试**: 涉及 `create_response` 的测试，如 `test/my_app/responses_test.exs:51` (valid), `test/my_app/responses_test.exs:90` (missing text), `test/my_app/responses_test.exs:106` (missing radio), `test/my_app/responses_test.exs:117` (invalid radio value), `test/my_app/responses_test.exs:129` (draft form), `test/my_app/responses_test.exs:138` (non-existent form)。

9.  **实现 `MyApp.Responses.get_response/1`**
    *   [x] 在 `lib/my_app/responses.ex` 中定义 `get_response/1` 函数。
    *   [x] 使用 `Repo.get/2` 获取 `Response`。
    *   [x] 使用 `Repo.preload/2` 预加载 `:answers` 关联。
    *   [x] **取消注释测试断言**: 回到 `test/my_app/responses_test.exs` 中 `get_response/1` 的测试，取消关于 `answers` 预加载和内容的断言注释。
    *   [x] **运行测试**: `test/my_app/responses_test.exs:149` (get valid), `test/my_app/responses_test.exs:180` (get non-existent)。

10. **实现 `MyApp.Responses.list_responses_for_form/1`**
    *   [x] 在 `lib/my_app/responses.ex` 中定义 `list_responses_for_form/1` 函数。
    *   [x] 使用 `Ecto.Query` 构建查询，根据 `form_id` 筛选 `Response`。
    *   [x] 使用 `Repo.all/1` 执行查询。
    *   [x] (可选) 根据需要决定是否预加载 `:answers`。
    *   [x] **运行测试**: `test/my_app/responses_test.exs:189` (list valid), `test/my_app/responses_test.exs:218` (list empty), `test/my_app/responses_test.exs:223` (list non-existent form)。

---

## 阶段三：表单系统前端实现

### 步骤 1-5：基础准备工作 (第一优先级)

1. **[ ] 组件库开发**
   * [ ] 创建 `lib/my_app_web/components/form_components.ex`
     * [ ] 实现 `form_header/1`：表单头部显示组件
     * [ ] 实现 `text_input_field/1`：文本输入字段组件
     * [ ] 实现 `radio_field/1`：单选按钮字段组件

2. **[ ] 共享布局更新**
   * [ ] 更新 `lib/my_app_web/templates/layout/app.html.heex`
     * [ ] 添加表单系统导航链接
   * [ ] 创建 `lib/my_app_web/templates/layout/form.html.heex`
     * [ ] 专用于表单显示的简洁布局

3. **[ ] CSS样式准备**
   * [ ] 创建 `assets/css/form.css`
     * [ ] 基础表单组件样式
     * [ ] 定义表单布局网格
     * [ ] 响应式样式规则

4. **[ ] 路由配置**
   * [ ] 在 `lib/my_app_web/router.ex` 中添加表单管理路由
     ```elixir
     scope "/", MyAppWeb do
       pipe_through [:browser, :require_authenticated_user]
       
       # 表单管理
       live "/forms", FormLive.Index, :index
       live "/forms/new", FormLive.New, :new
       live "/forms/:id/edit", FormLive.Edit, :edit
     end
     ```

5. **[ ] 基础JavaScript功能**
   * [ ] 在 `assets/js/app.js` 中添加表单相关功能
   * [ ] 创建 `assets/js/form-builder.js` 的基础结构

### 步骤 6-10：表单管理功能 (第二优先级)

6. **[ ] 表单列表页面**
   * [ ] 创建 `lib/my_app_web/live/form_live/index.ex`
     * [ ] 实现 `mount/3`：加载所有表单列表
     * [ ] 实现 `handle_event/3`：处理表单发布、删除操作
   * [ ] 创建 `lib/my_app_web/live/form_live/index.html.heex`
     * [ ] 表单列表表格视图
     * [ ] 操作按钮（编辑、发布、查看响应、删除）
     * [ ] 新建表单按钮

7. **[ ] 表单创建页面**
   * [ ] 创建 `lib/my_app_web/live/form_live/new.ex`
     * [ ] 实现 `mount/3`：初始化新表单
     * [ ] 实现 `handle_event/3`：处理表单保存
   * [ ] 创建 `lib/my_app_web/live/form_live/form_component.ex`
     * [ ] 实现表单基本信息编辑组件
   * [ ] 创建 `lib/my_app_web/live/form_live/new.html.heex`
     * [ ] 表单标题、描述输入
     * [ ] 保存按钮

8. **[ ] 表单编辑基础功能**
   * [ ] 创建 `lib/my_app_web/live/form_live/edit.ex`
     * [ ] 实现 `mount/3`：加载已有表单数据
     * [ ] 实现基本 `handle_event/3` 处理
   * [ ] 创建 `lib/my_app_web/live/form_live/edit.html.heex`
     * [ ] 表单基本信息编辑
     * [ ] 基本表单项展示
     * [ ] 保存和发布按钮

9. **[ ] 表单项编辑组件**
   * [ ] 创建 `lib/my_app_web/components/form_item_component.ex`
     * [ ] 实现文本输入项编辑组件
     * [ ] 实现单选按钮项编辑组件
   * [ ] 更新 `lib/my_app_web/live/form_live/edit.ex`
     * [ ] 添加表单项添加功能
     * [ ] 添加表单项编辑功能

10. **[ ] 表单项高级管理**
    * [ ] 更新 `lib/my_app_web/live/form_live/edit.ex`
      * [ ] 实现表单项删除功能
      * [ ] 实现表单项排序功能
    * [ ] 完善 `assets/js/form-builder.js`
      * [ ] 实现拖放排序功能

### 步骤 11-15：表单填写功能 (第三优先级)

11. **[ ] 路由配置-公开表单**
    * [ ] 在 `lib/my_app_web/router.ex` 中添加公开表单路由
      ```elixir
      scope "/", MyAppWeb do
        pipe_through [:browser]
        
        # 公开表单填写
        live "/f/:id", PublicFormLive.Show, :show
        get "/f/:id/success", PublicFormController, :success
      end
      ```

12. **[ ] 表单字段显示组件**
    * [ ] 创建 `lib/my_app_web/components/form_field_component.ex`
      * [ ] 实现文本输入字段组件
      * [ ] 实现单选按钮字段组件
      * [ ] 实现字段验证功能

13. **[ ] 公开表单显示-基础**
    * [ ] 创建 `lib/my_app_web/live/public_form_live/show.ex`
      * [ ] 实现 `mount/3`：加载表单和表单项
    * [ ] 创建 `lib/my_app_web/live/public_form_live/show.html.heex`
      * [ ] 表单标题和说明显示
      * [ ] 基础表单字段渲染

14. **[ ] 公开表单-验证与提交**
    * [ ] 更新 `lib/my_app_web/live/public_form_live/show.ex`
      * [ ] 实现 `handle_event/3`：处理表单验证和提交
    * [ ] 更新 `lib/my_app_web/live/public_form_live/show.html.heex`
      * [ ] 添加验证反馈
      * [ ] 添加提交按钮

15. **[ ] 提交成功页面**
    * [ ] 创建 `lib/my_app_web/controllers/public_form_controller.ex`
      * [ ] 实现 `success/2` 动作
    * [ ] 创建 `lib/my_app_web/templates/public_form/success.html.heex`
      * [ ] 显示提交成功消息

### 步骤 16-20：响应管理功能 (第四优先级)

16. **[ ] 路由配置-响应管理**
    * [ ] 在 `lib/my_app_web/router.ex` 中添加响应管理路由
      ```elixir
      scope "/", MyAppWeb do
        pipe_through [:browser, :require_authenticated_user]
        
        # 响应管理
        live "/forms/:id/responses", ResponseLive.Index, :index
        live "/forms/:id/responses/:response_id", ResponseLive.Show, :show
      end
      ```

17. **[ ] 响应列表页面-基础**
    * [ ] 创建 `lib/my_app_web/live/response_live/index.ex`
      * [ ] 实现 `mount/3`：加载指定表单的所有响应
    * [ ] 创建 `lib/my_app_web/live/response_live/index.html.heex`
      * [ ] 基础响应列表表格
      * [ ] 查看详情链接

18. **[ ] 响应列表页面-高级功能**
    * [ ] 更新 `lib/my_app_web/live/response_live/index.ex`
      * [ ] 实现 `handle_params/3`：处理过滤和排序
    * [ ] 更新 `lib/my_app_web/live/response_live/index.html.heex`
      * [ ] 添加过滤和排序控件

19. **[ ] 响应详情页面-基础**
    * [ ] 创建 `lib/my_app_web/live/response_live/show.ex`
      * [ ] 实现 `mount/3`：加载响应详情及关联答案
    * [ ] 创建 `lib/my_app_web/live/response_live/show.html.heex`
      * [ ] 显示提交时间、回答者信息
      * [ ] 显示问题和答案配对

20. **[ ] 响应详情页面-高级功能**
    * [ ] 更新 `lib/my_app_web/live/response_live/show.html.heex`
      * [ ] 添加导出按钮
    * [ ] 在 `lib/my_app_web/live/response_live/show.ex` 中添加导出功能

---

**注意:**

*   每完成一步（或一个函数的实现），都应该运行相关的测试 (`mix test path/to/test.exs:line_number` 或 `mix test path/to/file.exs`) 确认其通过，并运行 `mix test test/my_app/forms_test.exs test/my_app/responses_test.exs` 确保没有破坏其他测试。
*   迁移文件的编写需要仔细，确保字段类型、约束与 Schema 定义一致。
*   `create_response/2` 的验证逻辑是核心，需要仔细设计。
*   记得在实现预加载后，**取消测试中断言的注释**。
*   前端实现采用Phoenix LiveView，充分利用其实时交互特性进行表单验证和动态更新。
*   组件设计应考虑可重用性，便于扩展新的表单项类型。
*   表单填写页面应关注用户体验，确保在移动设备上也能良好工作。