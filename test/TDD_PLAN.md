# 自定义表单系统 TDD 计划

**当前进度：已完成核心功能测试用例编写，准备实现业务代码**

**遵循 TDD 流程：先写失败的测试 -> 编写最少代码让测试通过 -> 重构。**

---

## 阶段一：核心 Form 功能测试

1.  **基础 Form 创建与获取:**
    *   测试 `create_form/1`:
        *   [x] 成功创建一个只包含 `title` 的表单，状态为 `:draft`。
            *   (`test "create_form/1 with valid data creates a form"`)
        *   [x] 创建时缺少 `title` 返回错误。
            *   (`test "create_form/1 with invalid data returns error changeset"`)
    *   测试 `get_form/1`:
        *   [x] 成功获取已创建的表单。
            *   (`test "get_form/1 returns the form with given id"`)
        *   [x] 获取不存在的 `form_id` 返回 `nil` 或错误。
            *   (`test "get_form/1 returns nil for non-existent form id"`)

2.  **添加核心 FormItem (Text Input):**
    *   测试 `add_form_item/2`:
        *   [x] 成功添加 `:text_input` 项 (含 `label`, `type`) 到表单。
            *   (`test "with valid data adds a text_input item to the form"`)
        *   [x] `get_form/1` 能获取到新添加的项。
            *   (验证包含在 `test "with valid data adds a text_input item to the form"` 内，后续可通过 `get_form` 预加载验证)
        *   [x] 添加缺少 `label` 或 `type` 的项返回错误。
            *   (`test "returns error changeset if label is missing"`)
            *   (`test "returns error changeset if type is missing"`)
        *   [x] 验证 `order` 是否正确生成。
            *   (`test "assigns sequential order to newly added items"`)

3.  **添加核心 FormItem (Radio) 及 Options:**
    *   测试 `add_form_item/2`:
        *   [x] 成功添加 `:radio` 项到表单。
            *   (`test "with valid data adds a radio item to the form"`)
    *   测试 `add_item_option/3`:
        *   [x] 成功为 `:radio` 项添加至少两个选项 (含 `label`, `value`)。
            *   (`test "with valid data adds an option to a radio item"`)
        *   [x] `get_form/1` 能获取到 `:radio` 项及其选项。
            *   (验证包含在 `test "with valid data adds an option to a radio item"` 内，后续可通过 `get_form` 预加载验证)
        *   [x] 添加缺少 `label` 或 `value` 的选项返回错误。
            *   (`test "returns error changeset if label is missing"`)
            *   (`test "returns error changeset if value is missing"`)
        *   [x] 验证选项 `order` 是否正确生成。
            *   (`test "assigns sequential order to newly added options"`)

4.  **发布 Form:**
    *   测试 `publish_form/1`:
        *   [x] 成功将 `:draft` 表单更新为 `:published`。
            *   (`test "changes the form status from :draft to :published"`)
        *   [x] `get_form/1` 获取表单时状态为 `:published`。
            *   (验证包含在 `test "changes the form status from :draft to :published"` 内)
        *   [x] (可选) 尝试发布已发布的表单。
            *   (`test "returns error if the form is already published"`)

---

## 阶段二：核心 Response 功能测试

*   **前提**: 准备一个已发布的 `Form`，包含必填的 `:text_input` 和 `:radio` 项。

5.  **创建有效 Response:**
    *   测试 `create_response/2`:
        *   [x] 成功为 `:published` 表单提交有效响应（包含所有必填项）。
            *   (`test "with valid data creates a response and associated answers"`)
        *   [x] 验证 `answers_map` 结构和值的类型。
            *   (包含在 `test "with valid data creates a response and associated answers"` 的断言中)
        *   [x] 验证 `:radio` 的 `value` 是有效选项之一。
            *   (包含在 `test "with valid data creates a response and associated answers"` 的准备数据及断言中)
        *   [x] 验证返回 `{:ok, response}` 且 `response` 包含正确 `form_id` 和 `submitted_at`。
            *   (包含在 `test "with valid data creates a response and associated answers"` 的断言中)

6.  **验证 Response 创建时的约束:**
    *   测试 `create_response/2` 失败场景：
        *   [x] 缺少必填 `:text_input` 答案返回错误。
            *   (`test "returns error if required text_input answer is missing"`)
        *   [x] 缺少必填 `:radio` 答案返回错误。
            *   (`test "returns error if required radio answer is missing"`)
        *   [x] `:radio` 答案 `value` 无效返回错误。
            *   (`test "returns error if radio answer value is not a valid option"`)
        *   [x] 对 `:draft` 表单提交返回错误。
            *   (`test "returns error when submitting to a non-published form"`)
        *   [x] 对不存在的 `form_id` 提交返回错误。
            *   (`test "returns error when submitting to a non-existent form_id"`)

7.  **获取 Response:**
    *   测试 `get_response/1`:
        *   [x] 成功获取已创建的响应。
            *   (`test "returns the response with the given id, preloading answers"`)
        *   [x] 验证获取到的 `Answer` 记录的 `form_item_id` 和 `value`。
            *   (包含在 `test "returns the response with the given id, preloading answers"` 的注释掉的验证部分，需后续实现 `Answer` Schema 和预加载后取消注释)
        *   [x] 获取不存在的 `response_id` 时，是否返回 `nil` 或错误。
            *   (`test "returns nil if response id does not exist"`)
    *   测试 `list_responses_for_form/1`:
        *   [x] 成功列出指定 `form_id` 的所有响应。
            *   (`test "returns all responses submitted for a given form"`)
            *   (`test "returns an empty list if no responses exist for the form"`)
            *   (`test "returns an empty list for a non-existent form_id"`)

---

## 阶段三：前端 LiveView 功能测试

表单系统的前端测试计划，专注于可观测行为而非实现细节：

### 已完成的前端测试

1. **表单列表页面测试**
   - [x] 测试 `显示创建新表单按钮`
   - [x] 测试 `未登录用户被重定向到登录页面`
   - [x] 测试 `显示用户的表单列表`
   - [x] 测试 `只显示当前用户的表单`

2. **表单创建功能测试**
   - [x] 测试 `点击创建按钮显示表单创建界面`
   - [x] 测试 `成功创建表单后跳转到编辑页面`
   - [x] 测试 `表单标题为空时显示错误`
   - [x] 测试 `取消创建表单操作`
   - [x] 测试 `表单创建验证前端反馈`
   - [x] 测试 `表单创建WebSocket提交`

3. **JavaScript钩子测试**
   - [x] 测试 `FormHook的挂载和连接`
   - [x] 测试 `前端表单验证事件触发`
   - [x] 测试 `前端表单错误显示同步`

### 已编写但待执行的前端测试

4. **表单编辑功能测试** - `/test/my_app_web/live/form_live/edit_test.exs`
   - [x] 测试 `访问编辑页面`
   - [x] 测试 `编辑表单信息`
   - [x] 测试 `添加表单项`
   - [x] 测试 `编辑表单项`
   - [x] 测试 `删除表单项`
   - [x] 测试 `发布表单`
   - [x] 测试 `未经授权用户不能编辑表单`

5. **表单发布和查看功能测试** - `/test/my_app_web/live/form_live/show_test.exs`
   - [x] 测试 `表单显示页面加载`
   - [x] 测试 `表单项显示正确`
   - [x] 测试 `提供编辑和填写链接`
   - [x] 测试 `已发布表单显示状态`
   - [x] 测试 `其他用户不能查看草稿表单`
   - [x] 测试 `其他用户可以查看已发布表单`

6. **表单提交功能测试** - `/test/my_app_web/live/form_live/submit_test.exs`
   - [x] 测试 `表单提交页面加载`
   - [x] 测试 `表单字段正确显示`
   - [x] 测试 `表单验证 - 显示错误提示`
   - [x] 测试 `表单验证 - 文本字段`
   - [x] 测试 `表单验证 - 单选字段`
   - [x] 测试 `成功提交表单`
   - [x] 测试 `草稿表单不能提交`

7. **表单响应查看功能测试** - `/test/my_app_web/live/form_live/responses_test.exs`
   - [x] 测试 `访问表单响应列表页面`
   - [x] 测试 `显示响应列表`
   - [x] 测试 `查看详细响应`
   - [x] 测试 `删除响应`
   - [x] 测试 `其他用户不能查看响应`
   - [x] 测试 `查看响应详情`
   - [x] 测试 `返回响应列表`

8. **组件单元测试** - `/test/my_app_web/components/form_components_test.exs`
   - [x] 测试 `form_header/1`组件渲染
   - [x] 测试 `text_input_field/1`组件渲染和交互
   - [x] 测试 `radio_field/1`组件渲染和交互
   - [x] 测试 `form_builder/1`组件的整体功能

## 阶段四：后续扩展（根据需要逐步进行）

*   **Form 模块:**
    *   [ ] 测试 `update_form/2`
    *   [ ] 测试 `update_form_item/2`
    *   [ ] 测试 `update_item_option/3`
    *   [ ] 测试删除 `Form`, `FormItem`, `ItemOption` 及关联数据处理
    *   [ ] 测试 `reorder_form_items/2`
    *   [ ] 测试 `archive_form/1`
    *   [ ] 测试添加其他类型 `FormItem` (`:checkbox`, `:dropdown`, `:textarea`, `:rating`)
    *   [ ] 测试 `required` 属性和 `validation_rules`
    *   [ ] 测试 `LogicRule` 相关功能 (如果实现)
*   **Response 模块:**
    *   [ ] 测试非必填项处理
    *   [ ] 测试其他类型表单项的响应提交和验证
    *   [ ] 测试 `validation_rules` 的应用
    *   [ ] 测试 `delete_response/1`
    *   [ ] 测试分析和摘要功能 (如果实现)
    *   [ ] 测试 `Form`/`FormItem` 删除对 `Response`/`Answer` 的影响

---

## 待办事项和注意

*   **后续测试覆盖**: 当前测试已覆盖阶段一、二的核心流程，但以下功能尚未编写测试 (对应阶段三及后续扩展)：
    *   `Form`, `FormItem`, `ItemOption` 的 `update` 和 `delete` 操作。
    *   `Response` 的 `delete` 操作。
    *   其他 `FormItem` 类型 (`:checkbox`, `:textarea`, `:dropdown`, `:rating` 等) 的添加和响应验证。
    *   `FormItem` 的 `validation_rules` (例如：文本格式、长度限制)。
    *   表单项重新排序 (`reorder_form_items/2`)。
    *   表单归档 (`archive_form/1`)。
    *   响应者信息 (`respondent_info`) 的处理。
    *   逻辑规则 (`LogicRule`) 相关功能 (如果计划实现)。
    *   响应分析和摘要功能 (如果计划实现)。

*   **取消注释预加载断言**: 在实现 Ecto Schema 和相应的 Context 函数后，**务必**回到以下测试用例中，取消关于预加载关联数据 (`items`, `options`, `answers`) 的断言注释，以确保数据关联正确：
    *   `test/my_app/forms_test.exs`
        *   `test "with valid data adds a text_input item to the form"` (验证 `items`)
        *   `test "with valid data adds an option to a radio item"` (验证 `options`)
        *   `test "changes the form status from :draft to :published"` (验证持久化状态 - 可通过 `get_form` 验证)
    *   `test/my_app/responses_test.exs`
        *   `test "with valid data creates a response and associated answers"` (验证 `answers`)
        *   `test "returns the response with the given id, preloading answers"` (验证 `answers` 预加载和内容) 