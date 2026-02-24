# 更新日志

所有显著的变更都会记录在此文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，版本遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [Unreleased]
### 新增
- 初始项目结构搭建
- 系统检测模块：自动识别发行版、包管理器、WSL 环境、网络连通性
- DNS 优化模块：支持 systemd-resolved 和 /etc/resolv.conf，提供阿里、腾讯、Cloudflare 等公共 DNS 选项，自动备份
- 系统镜像优化模块：支持 apt、yum/dnf、pacman、brew，提供中国大陆（阿里、清华、中科大、华为云等）、海外镜像源，支持恢复官方源
- 开发工具镜像优化模块：为 npm、pnpm、yarn、pip、docker 配置国内镜像
- GitHub 访问优化模块：更新 hosts 或设置代理环境变量（需用户确认）
- 回滚功能：基于备份清单，支持按序号或全部回滚
- 日志系统：记录所有操作，便于排查
- 多语言支持：中文/英文双语，通过 `--lang` 切换
- 彩色输出：优化用户体验
- 命令行参数：支持 `--yes`、`--dry-run`、指定模块运行等
- 模块化设计：所有功能独立存放于 `modules/`，便于扩展
- 轻量版脚本 `ChangeMirrorsLite.sh`：仅含系统镜像优化功能
- GitHub Actions 持续集成：ShellCheck 检查、多发行版容器测试
- 单元测试框架（bats）及基础测试用例

### 修复
- 修复 Debian 系统下因缺少 lsb_release 导致的代号获取失败
- 修复模块发现函数因注释缺失导致的空菜单
- 修复 `system_mirror.sh` 中未定义变量错误

### 变更
- 增强备份/回滚机制，支持按时间点选择
- 改进模块元数据，为插件系统做准备
