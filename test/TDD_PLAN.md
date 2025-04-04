# 自定义表单系统 TDD 计划

**当前进度：编写测试**

**遵循 TDD 流程：先写失败的测试 -> 编写最少代码让测试通过 -> 重构。**

---

## 阶段一：核心 Form 功能测试

1.  **基础 Form 创建与获取:**
    *   测试 `create_form/1`:
        *   [ ] 成功创建一个只包含 `title` 的表单，状态为 `:draft`。
        *   [ ] 创建时缺少 `title` 返回错误。
    *   测试 `get_form/1`:
        *   [ ] 成功获取已创建的表单。
        *   [ ] 获取不存在的 `form_id` 返回 `nil` 或错误。

2.  **添加核心 FormItem (Text Input):**
    *   测试 `add_form_item/2`:
        *   [ ] 成功添加 `:text_input` 项 (含 `label`, `type`) 到表单。
        *   [ ] `get_form/1` 能获取到新添加的项。
        *   [ ] 添加缺少 `label` 或 `type` 的项返回错误。
        *   [ ] 验证 `order` 是否正确生成。

3.  **添加核心 FormItem (Radio) 及 Options:**
    *   测试 `add_form_item/2`:
        *   [ ] 成功添加 `:radio` 项到表单。
    *   测试 `add_item_option/3`:
        *   [ ] 成功为 `:radio` 项添加至少两个选项 (含 `label`, `value`)。
        *   [ ] `get_form/1` 能获取到 `:radio` 项及其选项。
        *   [ ] 添加缺少 `label` 或 `value` 的选项返回错误。
        *   [ ] 验证选项 `order` 是否正确生成。

4.  **发布 Form:**
    *   测试 `publish_form/1`:
        *   [ ] 成功将 `:draft` 表单更新为 `:published`。
        *   [ ] `get_form/1` 获取表单时状态为 `:published`。
        *   [ ] (可选) 尝试发布已发布的表单。

---

## 阶段二：核心 Response 功能测试

*   **前提**: 准备一个已发布的 `Form`，包含必填的 `:text_input` 和 `:radio` 项。

5.  **创建有效 Response:**
    *   测试 `create_response/2`:
        *   [ ] 成功为 `:published` 表单提交有效响应（包含所有必填项）。
        *   [ ] 验证 `answers_map` 结构和值的类型。
        *   [ ] 验证 `:radio` 的 `value` 是有效选项之一。
        *   [ ] 验证返回 `{:ok, response}` 且 `response` 包含正确 `form_id` 和 `submitted_at`。

6.  **验证 Response 创建时的约束:**
    *   测试 `create_response/2` 失败场景：
        *   [ ] 缺少必填 `:text_input` 答案返回错误。
        *   [ ] 缺少必填 `:radio` 答案返回错误。
        *   [ ] `:radio` 答案 `value` 无效返回错误。
        *   [ ] 对 `:draft` 表单提交返回错误。
        *   [ ] 对不存在的 `form_id` 提交返回错误。

7.  **获取 Response:**
    *   测试 `get_response/1`:
        *   [ ] 成功获取已创建的响应。
        *   [ ] 验证获取到的 `Answer` 记录的 `form_item_id` 和 `value`。
    *   测试 `list_responses_for_form/1`:
        *   [ ] 成功列出指定 `form_id` 的所有响应。

---

## 阶段三：后续扩展（根据需要逐步进行）

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