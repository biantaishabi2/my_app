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
    *   [ ] 在 `lib/my_app/forms.ex` 中定义 `publish_form/1` 函数。
    *   [ ] 检查传入表单的当前 `status`。如果不是 `:draft`，返回错误（如 `{:error, :already_published}` 或 `{:error, :invalid_status}`）。
    *   [ ] 如果是 `:draft`，使用 `Form.changeset/2` (或创建专用 changeset) 将 `status` 更新为 `:published`。
    *   [ ] 使用 `Repo.update/1` 更新表单。
    *   [ ] **运行测试**: `test/my_app/forms_test.exs:183` (publish draft), `test/my_app/forms_test.exs:194` (re-publish published)。

---

## 阶段二：实现核心 `Response` 模块功能

7.  **数据库基础 (Responses 相关)**
    *   [ ] **生成迁移文件**: 运行 `mix ecto.gen.migration create_responses_tables` (或类似，包含 responses, answers)。
    *   [ ] **编写迁移**: 在迁移文件中定义 `responses`, `answers` 表的结构，包括字段 (`submitted_at`, `respondent_info`, `value` - 推荐 `map` 或 `jsonb`)、类型、约束、索引、外键。
    *   [ ] **运行迁移**: 运行 `mix ecto.migrate` 创建数据库表。

8.  **实现 `MyApp.Responses.create_response/2`**
    *   [ ] 在 `lib/my_app/responses.ex` 中定义 `create_response/2` 函数 (接收 `form_id` 和 `answers_map`)。
    *   [ ] 引入 `Repo`, `MyApp.Responses.Response`, `MyApp.Responses.Answer`, `MyApp.Forms` 别名。
    *   [ ] **获取并验证表单**: 使用 `Forms.get_form/1` 获取 `form_id` 对应的表单，并预加载 `items` 及其 `options` (`Repo.preload(form, [items: :options])`)。验证表单是否存在且状态为 `:published`。
    *   [ ] **验证答案**: 
        *   遍历表单的 `items`。
        *   检查必填项 (`required: true`) 是否在 `answers_map` 中存在答案。
        *   对于 `:radio` (及后续 `:dropdown`) 类型，验证 `answers_map` 中的值是否是该 `item` 的有效 `option.value` 之一。
        *   (后续可添加其他验证，如 `:text_input` 格式)。
        *   如果验证失败，返回 `{:error, reason}` (例如 `{:error, :validation, changeset}` 或 `{:error, :invalid_answer, item_id}`）。
    *   [ ] **构建数据**: 如果验证通过，创建 `Response` 结构 (设置 `submitted_at`, `form_id`) 和 `Answer` 结构列表 (设置 `value`, `form_item_id`)。
    *   [ ] **原子化插入**: 使用 `Repo.transaction/1` 和 `Ecto.Multi`，将 `Response` 和所有 `Answers` 一起插入数据库。
    *   [ ] **运行测试**: 涉及 `create_response` 的测试，如 `test/my_app/responses_test.exs:51` (valid), `test/my_app/responses_test.exs:90` (missing text), `test/my_app/responses_test.exs:106` (missing radio), `test/my_app/responses_test.exs:117` (invalid radio value), `test/my_app/responses_test.exs:129` (draft form), `test/my_app/responses_test.exs:138` (non-existent form)。

9.  **实现 `MyApp.Responses.get_response/1`**
    *   [ ] 在 `lib/my_app/responses.ex` 中定义 `get_response/1` 函数。
    *   [ ] 使用 `Repo.get/2` 获取 `Response`。
    *   [ ] 使用 `Repo.preload/2` 预加载 `:answers` 关联。
    *   [ ] **取消注释测试断言**: 回到 `test/my_app/responses_test.exs` 中 `get_response/1` 的测试，取消关于 `answers` 预加载和内容的断言注释。
    *   [ ] **运行测试**: `test/my_app/responses_test.exs:149` (get valid), `test/my_app/responses_test.exs:180` (get non-existent)。

10. **实现 `MyApp.Responses.list_responses_for_form/1`**
    *   [ ] 在 `lib/my_app/responses.ex` 中定义 `list_responses_for_form/1` 函数。
    *   [ ] 使用 `Ecto.Query` 构建查询，根据 `form_id` 筛选 `Response`。
    *   [ ] 使用 `Repo.all/1` 执行查询。
    *   [ ] (可选) 根据需要决定是否预加载 `:answers`。
    *   [ ] **运行测试**: `test/my_app/responses_test.exs:189` (list valid), `test/my_app/responses_test.exs:218` (list empty), `test/my_app/responses_test.exs:223` (list non-existent form)。

---

**注意:**

*   每完成一步（或一个函数的实现），都应该运行相关的测试 (`mix test path/to/test.exs:line_number` 或 `mix test path/to/file.exs`) 确认其通过，并运行 `mix test test/my_app/forms_test.exs test/my_app/responses_test.exs` 确保没有破坏其他测试。
*   迁移文件的编写需要仔细，确保字段类型、约束与 Schema 定义一致。
*   `create_response/2` 的验证逻辑是核心，需要仔细设计。
*   记得在实现预加载后，**取消测试中断言的注释**。 