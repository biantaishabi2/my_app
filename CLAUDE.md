# CLAUDE.md - 操作指南

## 测试文件修改原则

**重要规则**：永远不要去修改测试文件，不到迫不得已的时候。如果确实需要修改测试文件，必须先征求用户的同意。这是因为测试文件中可能有严重的错误或特定的期望，修改它们可能会导致测试的有效性问题。

应遵循的方法是：
1. 分析测试文件以理解测试期望的行为
2. 调整业务代码以匹配测试期望，而不是反过来
3. 只有在获得明确授权后才能修改测试文件

## 调试与修复策略

1. **错误分析**：在修改代码前先彻底分析问题根源
   - 确定问题是数据流问题、业务逻辑问题还是显示问题
   - 使用日志记录关键步骤，跟踪数据流向
   - 确认参数传递、类型转换和数据检索过程

2. **分层修复顺序**：
   - 先确保数据结构和类型正确（例如atom vs string键、关联数据加载等）
   - 再修复业务流程和数据转换逻辑
   - 最后处理UI渲染和显示相关逻辑

3. **实现与测试分离**：
   - 不应在业务代码中添加专为测试环境设计的特殊逻辑
   - 避免使用`if Mix.env() == :test`这类条件语句
   - 业务代码应正确实现功能，而不是为了通过测试而添加特殊处理

## 测试驱动开发策略

1. **组件测试原则**：
   - 测试组件的行为而非实现细节
   - 避免对HTML结构或CSS类名的硬编码依赖
   - 对于表单控件，测试渲染、数据处理、验证和状态展示
   - 组件测试放在`form_components_test.exs`中

2. **页面测试原则**：
   - 关注页面级工作流和状态变化
   - 测试用户操作导致的数据处理结果
   - 编辑页面测试放在`edit_test.exs`中，不测试组件内部实现

3. **后端模型测试原则**：
   - 测试数据模型、验证规则和业务逻辑
   - 不涉及UI或展示层细节
   - 控件后端逻辑测试放在`forms_test.exs`中

4. **TDD流程**：
   - 先写测试定义预期行为
   - 实现最小代码使测试通过
   - 重构代码提高质量，保持测试通过
   - 每个表单控件都应该遵循此流程实现
   
5. **行为测试而非实现测试**：
   - 测试应该关注功能行为而非实现细节
   - 优先测试事件和结果，而非具体UI元素（如按钮文本）
   - 可以直接使用`render_click/2`触发命名事件而非依赖特定UI元素
   - 这种方法使测试更稳定，在UI变更时不易失败

## 测试运行策略

1. **选择性测试运行**：
   - 运行所有表单系统测试时，不要包括chat相关的测试
   - 表单系统的测试命令: `mix test test/my_app/forms_test.exs test/my_app/responses_test.exs test/my_app_web/live/form_live/`
   - 避免运行不相关模块的测试以节省时间并减少不必要的错误干扰

2. **聚焦失败测试**：
   - 当发现特定测试失败时，优先单独运行该测试进行调试
   - 使用`mix test <specific_test_file:line_number>`来运行单个测试案例

## 调试技巧

### 使用 systemd 管理服务和日志

为了更稳定、更方便地管理 Phoenix 应用程序服务和查看日志，推荐使用 `systemd` 进行管理。

1.  **创建 systemd 服务文件** (`/etc/systemd/system/my_app.service`)：
    ```ini
    [Unit]
    Description=My Phoenix Application Service (MyApp)
    After=network.target

    [Service]
    User=wangbo
    WorkingDirectory=/home/wangbo/document/wangbo/my_app
    Environment="MIX_ENV=dev" # 注意：生产环境应使用 prod 并运行 release
    Environment="HOME=/home/wangbo"
    # 确保 PATH 包含 mix 命令的路径
    Environment="PATH=/home/wangbo/.local/bin:/home/wangbo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin" 
    ExecStart=/usr/bin/mix phx.server
    Restart=on-failure
    RestartSec=5s
    StandardOutput=journal
    StandardError=journal

    [Install]
    WantedBy=multi-user.target
    ```

2.  **管理服务**:
    *   **重载配置** (创建或修改服务文件后): `sudo systemctl daemon-reload`
    *   **启动服务**: `sudo systemctl start my_app.service`
    *   **停止服务**: `sudo systemctl stop my_app.service`
    *   **重启服务**: `sudo systemctl restart my_app.service`
    *   **查看状态**: `sudo systemctl status my_app.service`
    *   **设置开机自启**: `sudo systemctl enable my_app.service`
    *   **取消开机自启**: `sudo systemctl disable my_app.service`

3.  **查看日志**:
    *   **查看所有日志**: `sudo journalctl -u my_app.service`
    *   **实时跟踪日志**: `sudo journalctl -u my_app.service -f`
    *   **查看最近N行日志**: `sudo journalctl -u my_app.service -n 50` (查看最近50行)
    *   **根据时间过滤**: `sudo journalctl -u my_app.service --since "10 minutes ago"`

使用 `systemd` 的优势：
- 标准化的服务管理命令。
- 集成的日志系统 (`journald`)，无需手动管理日志文件。
- 可以方便地查看服务状态和错误信息。
- 可配置自动重启等高级功能。

### 利用Phoenix的热重载功能

Phoenix支持代码热重载，这意味着大多数代码更改会自动应用，无需重启服务器：
- 编辑代码文件并保存
- Phoenix会自动重新编译和重新加载更改
- 监控日志以确认更改已应用

## 其他注意事项

- 业务代码应该遵循代码库中的风格和约定
- 避免在业务代码中添加特定于测试的逻辑，除非这是唯一选择
- 保持代码简洁且易于理解
- 每次测试运行了以后要总结一下这次测试的进展以及剩下的问题
- 考虑通用性设计，避免只针对特定测试用例的硬编码解决方案
- 新控件开发应先实现测试，再实现功能
