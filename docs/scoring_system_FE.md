# 评分系统 LiveView 前端设计

## 实施状态

**更新日期**: 2025-04-15

**实施状态**: ⚠️ 大部分已实现，评分规则编辑器需改进

评分系统前端界面大部分已实现，包括计划的LiveView页面和组件。系统支持以下功能：

- 评分规则管理（创建、编辑、删除规则）
- 表单评分配置
- 查看和导出回答评分
- 自动评分处理
- 评分结果展示

**待实施改进**：
评分规则编辑器组件需要重新设计正确答案输入方式，使其适应不同类型的表单控件。

## 评分规则编辑器改进计划

### 问题描述

当前的评分规则编辑器(`ScoreRuleEditorComponent`)使用统一的文本输入作为"正确答案"输入方式，无法直观地处理不同类型的表单控件(单选、多选、日期等)。这导致用户体验不佳，且容易出错。

### 改进目标

根据所选题目的类型，动态显示与之匹配的答案输入控件，使规则创建更直观、更准确。

### 具体改进任务

1. **数据结构增强**:
   - [x] 前端: 规则编辑器组件中添加对应表单项类型信息 (50%)
   - [ ] 前端: 扩展规则数据结构，支持不同类型控件的答案格式 (0%)
   - [ ] 后端: 完善规则验证逻辑，支持新的数据格式 (0%)

2. **动态答案输入界面**:
   - [ ] 前端: 实现根据题目类型动态切换答案输入控件 (0%)
   - [ ] 前端: 为不同控件类型提供专门的答案输入界面:
     - [ ] 单选题: 显示选项列表，直接选择 (0%)
     - [ ] 多选题: 显示复选框列表 (0%)
     - [ ] 评分题: 显示评分控件 (0%)
     - [ ] 日期/时间题: 显示日期/时间选择器 (0%)
     - [ ] 填空题: 多个文本输入框 (0%)
     - [ ] 图片选择题: 显示图片选项 (0%)
     - [ ] 文件上传题: 特殊处理逻辑 (0%)

3. **评分逻辑优化**:
   - [ ] 后端: 评分计算支持不同控件类型的专门逻辑 (0%)
   - [ ] 后端: 支持部分正确给部分分 (如多选题) (0%)
   - [ ] 后端: 填空题多空分别评分 (0%)

4. **用户体验优化**:
   - [ ] 前端: 添加控件类型图标提示 (0%)
   - [ ] 前端: 为特殊控件提供预览功能 (0%)
   - [ ] 前端: 添加帮助文本说明不同控件的评分方法 (0%)

### 实现步骤

1. **表单项类型信息获取**:
   - 在规则编辑器组件中，当选择题目后，获取并存储该题目的类型
   - 在模板中使用条件渲染，根据题目类型显示不同的答案输入控件

2. **控件类型专门处理**:
   - 对每种控件类型实现专门的答案输入组件
   - 使用现有的表单控件渲染逻辑，确保一致的用户体验

3. **数据格式调整**:
   - 调整规则数据结构，使其支持不同类型的答案格式
   - 例如多选题存储答案数组，日期题存储日期格式

4. **评分计算适配**:
   - 修改后端评分计算逻辑，支持新的数据格式
   - 为不同控件类型实现专门的评分算法

### 后端改动范围

- `scoring.ex`: 评分计算函数需修改，支持新的数据格式和控件类型
- `score_rule.ex`: 规则验证逻辑需要更新，适应新的数据结构
- 可能需要调整数据库字段，如果当前格式不足以存储复杂答案

### 前端改动范围

- `score_rule_editor_component.ex`: 核心改动，全面重构答案输入部分
- `score_rule_form_modal_component.ex`: 可能需要轻微调整以支持新的数据结构
- 可能需要新增辅助组件来渲染特定类型的答案输入控件

### 优先级和时间表

1. **高优先级** (当前冲刺):
   - 完成数据结构设计
   - 实现基本的动态控件切换
   - 优先支持核心控件类型: 单选、多选、文本输入

2. **中优先级** (下个冲刺):
   - 支持其余基本控件: 评分、日期、时间、下拉菜单
   - 优化用户体验，添加提示和帮助

3. **低优先级** (后续冲刺):
   - 支持复杂控件: 填空题、矩阵题、图片选择
   - 实现高级评分逻辑: 部分计分、关键词匹配等

### 影响和风险

- **用户体验**: 改进后的界面将大幅提升用户友好度，但可能需要短期适应
- **向后兼容**: 需确保现有规则数据仍能正常工作
- **性能影响**: 动态控件渲染可能增加客户端复杂度，需注意性能优化
- **测试需求**: 必须全面测试不同控件类型的评分逻辑，确保正确性

## 1. 概述

本文档描述了评分系统前端使用 Phoenix LiveView 的设计方案。前端界面将主要服务于表单创建者或管理员，允许他们管理评分规则、配置表单评分设置以及查看评分结果。

## 2. 页面 (LiveViews)

前端将包含以下主要 LiveView 页面：

### 2.1 评分规则管理 (列表与模态框表单)

*   **`ScoreRuleLive.Index`** (`/forms/:form_id/scoring/rules`)
    *   **职责**: 显示指定表单的所有评分规则列表。通过**模态框**处理创建和编辑操作。
    *   **包含组件**: `RuleListItemComponent`, `ScoreRuleFormModalComponent` (条件渲染)
    *   **后端交互**:
        *   `MyApp.Scoring.get_form/1` (加载表单信息)
        *   `MyApp.Scoring.get_score_rules_for_form/1` (获取规则列表)
        *   `MyApp.Scoring.delete_score_rule/2` (处理删除事件)
        *   `MyApp.Scoring.get_score_rule/1` (编辑时加载现有规则到模态框)
        *   `MyApp.Scoring.create_score_rule/2` (处理模态框创建表单提交)
        *   `MyApp.Scoring.update_score_rule/3` (处理模态框编辑表单提交)
    *   **路由**: 需要在 `router.ex` 中添加嵌套路由 (仅需 `:index` 路由)。

### 2.2 表单评分配置

*   **`FormScoreLive.Show`** (`/forms/:form_id/scoring/config`)
    *   **职责**: 显示和编辑指定表单的评分配置，如总分、通过分数、自动评分开关、分数可见性。
    *   **后端交互**:
        *   `MyApp.Scoring.get_form/1`
        *   `MyApp.Scoring.get_form_score_config/1` (加载当前配置)
        *   `MyApp.Scoring.setup_form_scoring/3` (处理表单提交以创建或更新配置)
    *   **路由**: 需要在 `router.ex` 中添加嵌套路由。

### 2.3 响应评分查看

*   **`ResponseScoreLive.Index`** (`/forms/:form_id/scoring/results`)
    *   **职责**: 显示指定表单的所有已提交响应及其评分结果列表。可能包含搜索/筛选功能。
    *   **包含组件**: `ScoreDisplayComponent`
    *   **后端交互**:
        *   `MyApp.Scoring.get_form/1`
        *   `MyApp.Responses.list_responses_for_form/1` (获取响应列表 - 假设存在)
        *   `MyApp.Scoring.get_response_scores_for_form/1` (获取评分列表 - **需要新建此函数** 或调整逻辑)
    *   **路由**: 需要在 `router.ex` 中添加嵌套路由。

*   **`ResponseScoreLive.Show`** (`/responses/:response_id/scoring/result`)
    *   **职责**: 显示单个响应的详细评分信息，可能包括每个问题的得分情况（如果 `ResponseScore` 的 `score_breakdown` 字段存储了这些信息）。
    *   **包含组件**: `ScoreDisplayComponent`
    *   **后端交互**:
        *   `MyApp.Responses.get_response/1` (加载响应信息)
        *   `MyApp.Scoring.get_response_score_for_response/1` (获取评分详情 - **需要新建此函数** 或调整逻辑)
    *   **路由**: 需要在 `router.ex` 中添加路由。

## 3. 可复用组件 (LiveComponents)

*   **`ScoreRuleFormModalComponent`** (新)
    *   **职责**: 封装评分规则创建/编辑表单的模态框。管理表单状态和验证，包含 `ScoreRuleEditorComponent`。
    *   **使用位置**: `ScoreRuleLive.Index` (在模态框中渲染)
    *   **输入**: 可能需要 `changeset` 或 `score_rule` (编辑时)
    *   **事件**: 向父 LiveView 发送保存、取消等事件。

*   **`ScoreRuleEditorComponent`**
    *   **职责**: 提供一个交互式的界面来编辑评分规则的 `rules` JSON 结构。这可能需要解析 JSON、动态添加/删除评分项、设置每个项的评分方法和答案等。
    *   **使用位置**: `ScoreRuleFormModalComponent`
    *   **状态**: 内部管理编辑状态，通过事件与父组件通信。

*   **`ScoreDisplayComponent`**
    *   **职责**: 以统一格式显示分数，例如 "85 / 100"。可以根据是否通过显示不同样式。
    *   **使用位置**: `ResponseScoreLive.Index`, `ResponseScoreLive.Show`
    *   **输入**: `score`, `max_score`, `passing_score` (可选)

*   **`RuleListItemComponent`**
    *   **职责**: 在评分规则列表中显示单个规则的摘要信息（名称、描述、激活状态）和操作按钮（编辑、删除）。
    *   **使用位置**: `ScoreRuleLive.Index`
    *   **输入**: `score_rule`
    *   **事件**: 发送编辑(打开模态框)、删除请求的事件给父 LiveView。

## 4. 后端 API 调整建议

为了更好地支持 LiveView 前端，建议在 `MyApp.Scoring` 上下文中添加以下函数：

*   `get_response_scores_for_form(form_id)`: 获取指定表单下所有响应的评分结果列表。
*   `get_response_score_for_response(response_id)`: 获取单个响应的评分结果。

## 5. 路由设计 (`router.ex`)

需要添加嵌套路由来组织评分相关的页面：

```elixir
# 在 :form_id 资源下
scope "/", MyAppWeb do
  pipe_through [:browser, :require_authenticated_user] # 假设需要登录

  live_session :default, on_mount: MyAppWeb.UserAuth do
    # ... 其他 live 路由 ...

    scope "/forms/:form_id" do
      # ... 其他表单相关 live 路由 ...
      scope "/scoring", Scoring do # 使用别名，假设在 MyAppWeb 下创建了 Scoring 目录
        live "/rules", ScoreRuleLive.Index, :index # 只需要 index 路由
        # live "/rules/new", ScoreRuleLive.Form, :new # 移除
        # live "/rules/:rule_id/edit", ScoreRuleLive.Form, :edit # 移除
        live "/config", FormScoreLive.Show, :show
        live "/results", ResponseScoreLive.Index, :index
      end
    end

    # 可能需要一个顶层路由来查看单个响应的评分
    live "/responses/:response_id/scoring/result", Scoring.ResponseScoreLive.Show, :show
  end
end
```

(注意: 上述路由中的模块名需要根据实际项目结构调整，例如 `MyAppWeb.Scoring` 或直接使用 `MyAppWeb.ScoreRuleLive` 等。)

## 6. 涉及文件

实现此设计将主要涉及以下文件 (总计约 16 个新文件 + 2 个修改文件)：

*   **LiveView 核心文件** (`lib/my_app_web/live/scoring/`)
    *   `score_rule_live/index.ex` & `.html.heex` (列表页 + 模态框逻辑)
    *   `form_score_live/show.ex` & `.html.heex`
    *   `response_score_live/index.ex` & `.html.heex`
    *   `response_score_live/show.ex` & `.html.heex`

*   **LiveComponent 文件** (`lib/my_app_web/live/scoring/components/`)
    *   `score_rule_form_modal_component.ex` & `.html.heex` (新，模态框表单)
    *   `score_rule_editor_component.ex` & `.html.heex` (规则 JSON 编辑器)
    *   `score_display_component.ex` & `.html.heex` (分数展示)
    *   `rule_list_item_component.ex` & `.html.heex` (规则列表项)

*   **路由文件** (修改)
    *   `lib/my_app_web/router.ex`

*   **后端上下文文件** (修改)
    *   `lib/my_app/scoring.ex` (可能需要添加新函数)

## 7. 实现计划与进度

1.  **[✓] 路由设置 (`lib/my_app_web/router.ex`)**
    *   **任务**: 根据设计文档第 5 节，在 `router.ex` 中添加评分系统相关的 LiveView 路由。
    *   **文件**: `lib/my_app_web/router.ex` (修改)
    *   **完成状态**: 已实现相关路由，包括规则管理、配置页面和评分结果查看页面

2.  **[✓] 后端 API 调整 (`lib/my_app/scoring.ex`)**
    *   **任务**: 实现设计文档第 4 节建议的两个新函数：`get_response_scores_for_form/1` 和 `get_response_score_for_response/1`。
    *   **文件**: `lib/my_app/scoring.ex` (修改)
    *   **完成状态**: 已添加两个新函数，并额外增加了`change_score_rule/1`函数用于模态框表单组件

3.  **[✓] 评分规则列表页 (`ScoreRuleLive.Index`)**
    *   **任务**: 创建基本的 `ScoreRuleLive.Index` LiveView，使其能够挂载、获取并显示指定表单的评分规则列表（暂时不包括模态框功能）。
    *   **涉及后端**: `Scoring.get_form/1`, `Scoring.get_score_rules_for_form/1`
    *   **文件**:
        *   `lib/my_app_web/live/scoring/score_rule_live/index.ex` (新建)
        *   `lib/my_app_web/live/scoring/score_rule_live/index.html.heex` (新建)
    *   **完成状态**: 已创建LiveView及相关模板

4.  **[✓] 规则列表项组件 (`RuleListItemComponent`)**
    *   **任务**: 创建 `RuleListItemComponent` 以在 `ScoreRuleLive.Index` 中渲染单个规则项，包含名称、描述和操作按钮（编辑、删除）。
    *   **文件**:
        *   `lib/my_app_web/live/scoring/components/rule_list_item_component.ex` (新建)
        *   `lib/my_app_web/live/scoring/components/rule_list_item_component.html.heex` (新建)
    *   **集成**: 在 `ScoreRuleLive.Index` 中使用此组件。
    *   **完成状态**: 已创建组件并集成到规则列表页

5.  **[✓] 评分规则删除功能 (`ScoreRuleLive.Index`)**
    *   **任务**: 在 `ScoreRuleLive.Index` 中实现删除规则的功能，处理来自 `RuleListItemComponent` 的删除事件。
    *   **涉及后端**: `Scoring.delete_score_rule/2`
    *   **文件**: `lib/my_app_web/live/scoring/score_rule_live/index.ex` (修改)
    *   **完成状态**: 已实现删除功能，包括确认对话框

6.  **[✓] 规则编辑核心组件 (`ScoreRuleEditorComponent`)**
    *   **任务**: 创建 `ScoreRuleEditorComponent`，专注于渲染和编辑 `rules` JSON 结构。初期可以先实现基本字段的展示和简单编辑。
    *   **文件**:
        *   `lib/my_app_web/live/scoring/components/score_rule_editor_component.ex` (新建)
        *   `lib/my_app_web/live/scoring/components/score_rule_editor_component.html.heex` (新建)
    *   **完成状态**: 已创建组件，支持编辑规则JSON结构

7.  **[✓] 评分规则模态框表单组件 (`ScoreRuleFormModalComponent`)**
    *   **任务**: 创建 `ScoreRuleFormModalComponent`，包含规则名称、描述等字段，并嵌入 `ScoreRuleEditorComponent`。处理表单的 `changeset` 和验证。
    *   **文件**:
        *   `lib/my_app_web/live/scoring/components/score_rule_form_modal_component.ex` (新建)
        *   `lib/my_app_web/live/scoring/components/score_rule_form_modal_component.html.heex` (新建)
    *   **完成状态**: 已创建模态框组件，集成了规则编辑器组件

8.  **[✓] 评分规则创建/编辑功能 (`ScoreRuleLive.Index`)**
    *   **任务**: 在 `ScoreRuleLive.Index` 中集成 `ScoreRuleFormModalComponent`，实现打开/关闭模态框、加载编辑数据、处理保存事件（创建和更新）。
    *   **涉及后端**: `Scoring.get_score_rule/1`, `Scoring.create_score_rule/2`, `Scoring.update_score_rule/3`
    *   **文件**: `lib/my_app_web/live/scoring/score_rule_live/index.ex` (修改), `index.html.heex` (修改)
    *   **完成状态**: 已在列表页面中集成模态框，实现创建和编辑功能

9.  **[✓] 表单评分配置页 (`FormScoreLive.Show`)**
    *   **任务**: 创建 `FormScoreLive.Show` LiveView，用于显示和编辑表单的评分配置。
    *   **涉及后端**: `Scoring.get_form/1`, `Scoring.get_form_score_config/1`, `Scoring.setup_form_scoring/3`
    *   **文件**:
        *   `lib/my_app_web/live/scoring/form_score_live/show.ex` (新建)
        *   `lib/my_app_web/live/scoring/form_score_live/show.html.heex` (新建)
    *   **完成状态**: 已创建页面，支持配置总分、通过分数等设置

10. **[✓] 响应评分结果列表页 (`ResponseScoreLive.Index`)**
    *   **任务**: 创建 `ResponseScoreLive.Index` LiveView，显示响应列表及其评分（如果已评分）。
    *   **涉及后端**: `Scoring.get_form/1`, `Responses.list_responses_for_form/1`, `Scoring.get_response_scores_for_form/1` (新函数)
    *   **文件**:
        *   `lib/my_app_web/live/scoring/response_score_live/index.ex` (新建)
        *   `lib/my_app_web/live/scoring/response_score_live/index.html.heex` (新建)
    *   **完成状态**: 已创建页面，显示评分状态并支持手动触发评分

11. **[✓] 分数展示组件 (`ScoreDisplayComponent`)**
    *   **任务**: 创建 `ScoreDisplayComponent`，用于在结果列表中统一显示分数。
    *   **文件**:
        *   `lib/my_app_web/live/scoring/components/score_display_component.ex` (新建)
        *   `lib/my_app_web/live/scoring/components/score_display_component.html.heex` (新建)
    *   **集成**: 在 `ResponseScoreLive.Index` 中使用。
    *   **完成状态**: 已创建组件，支持不同大小和根据是否及格显示不同样式

12. **[✓] 单个响应评分详情页 (`ResponseScoreLive.Show`)**
    *   **任务**: 创建 `ResponseScoreLive.Show` LiveView，显示单个响应的详细评分信息。
    *   **涉及后端**: `Responses.get_response/1`, `Scoring.get_response_score_for_response/1` (新函数)
    *   **文件**:
        *   `lib/my_app_web/live/scoring/response_score_live/show.ex` (新建)
        *   `lib/my_app_web/live/scoring/response_score_live/show.html.heex` (新建)
    *   **集成**: 在 `ResponseScoreLive.Index` 中添加链接到此页面，并在此页面使用 `ScoreDisplayComponent`。
    *   **完成状态**: 已创建页面，显示详细评分信息

13. **[✓] 完善和样式调整**
    *   **任务**: 对所有页面和组件进行样式美化、用户体验优化和最终测试。
    *   **完成状态**: 已添加合适的样式和布局，并创建辅助函数模块优化代码结构

## 8. 额外完成的工作

1. **[✓] 创建辅助函数模块**
   * 创建了 `lib/my_app_web/live/scoring/helpers.ex` 提供共享功能，如日期格式化、响应名称获取等
   * 减少了代码重复并提高了可维护性

2. **[✓] 添加Forms上下文辅助函数**
   * 在 `forms.ex` 中添加了 `list_form_items_for_form/1` 函数以支持评分规则编辑器
   * 确保了与现有代码的兼容性

3. **[✓] 路由和命名空间设计**
   * 所有路由和模块命名空间完全符合设计文档规范
   * 使用 `MyAppWeb.Scoring` 命名空间简化了组织结构

4. **[✓] 现代化路由语法**
   * 更新了所有导航代码，从deprecated的`push_redirect`迁移到`push_navigate`
   * 替换了旧的`Routes`路径助手为新的`~p`路径语法，提高代码可维护性

5. **[✓] 修复模型字段问题**
   * 修复了`FormScore`结构中的字段名称不匹配问题(将`max_score` -> `total_score`)
   * 确保了前后端字段名称的一致性
   
6. **[✓] 实现自动评分功能**
   * 添加表单提交后自动评分的功能，默认开启
   * 使用异步任务处理评分，不影响表单提交体验
   * 优化评分流程，移除重复的自动评分检查
