# 贡献指南

感谢您考虑为 devboost 做出贡献！以下是一些指导原则，帮助您顺利参与。

## 报告问题

- 使用 GitHub Issues 提交问题。
- 请描述清楚问题现象、运行环境（OS、版本）、复现步骤、相关日志（`logs/devboost.log`）。
- 如果是功能建议，请说明使用场景和期望行为。

## 提交 Pull Request

1. Fork 仓库并创建您的分支：`git checkout -b feature/your-feature`
2. 确保代码风格一致（使用 ShellCheck 检查）。
3. 添加或更新必要的测试（如果有）。
4. 更新文档（README、帮助信息等）。
5. 提交 PR 前请确保通过现有测试。
6. PR 描述请清楚说明改动内容和原因。

## 开发环境设置

```bash
git clone https://github.com/yourusername/devboost.git
cd devboost
chmod +x install.sh lib/*.sh modules/*.sh