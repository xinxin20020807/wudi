# Wudi - 现代化 FastAPI 应用

一个基于 FastAPI 的现代化 Web 应用，集成了完整的 GitOps CI/CD 流程。

## 🚀 特性

- **现代化技术栈**: FastAPI + Python 3.10+ + UV 包管理
- **GitOps CI/CD**: Tekton + Pipelines as Code + ArgoCD
- **容器化部署**: Docker 多阶段构建 + Kubernetes
- **开发工具链**: 代码格式化、类型检查、自动化测试
- **可观测性**: 健康检查、日志记录、安全头
- **最佳实践**: 非 root 用户、资源限制、安全配置

## 📁 项目结构

```
.
├── .tekton/                 # Tekton Pipeline 配置
│   ├── pipeline.yaml
│   ├── pipelinerun.yaml
│   └── tasks/
│       ├── git-clone.yaml
│       └── kaniko-build.yaml
├── templates/               # Jinja2 模板
├── main.py                  # 主应用文件
├── config.py               # 配置管理
├── middleware.py           # 中间件
├── test_main.py           # 测试文件
├── Dockerfile             # 容器构建文件
├── pyproject.toml         # 项目配置和依赖
├── Makefile              # 开发命令
├── TROUBLESHOOTING.md    # 故障排查指南
└── GITOPS-GUIDE.md       # GitOps 最佳实践
```

## 🛠️ 快速开始

### 本地开发

```bash
# 安装依赖
make install-dev

# 启动开发服务器
make dev

# 运行测试
make test

# 代码格式化
make format

# 代码检查
make lint
```

### Docker 部署

```bash
# 构建镜像
make docker-build

# 运行容器
make docker-run

# 测试镜像
make docker-test

# 停止容器
make docker-stop
```

## 🔧 配置说明

### 环境变量

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `APP_NAME` | wudi | 应用名称 |
| `APP_VERSION` | 0.1.0 | 应用版本 |
| `DEBUG` | False | 调试模式 |
| `HOST` | 0.0.0.0 | 服务器地址 |
| `PORT` | 8000 | 服务器端口 |
| `LOG_LEVEL` | info | 日志级别 |

### 健康检查

应用提供健康检查端点：

```bash
curl http://localhost:8000/health
```

响应示例：
```json
{
  "status": "healthy",
  "timestamp": "2024-01-01T00:00:00Z",
  "app_name": "wudi",
  "app_version": "0.1.0",
  "git_commit": "abc123"
}
```

## 🚀 CI/CD 流程

### Pipeline 触发

1. **Push 事件**: 推送到 main 分支触发完整部署
2. **PR 事件**: 创建 PR 触发构建和测试

### 部署流程

1. **源码克隆**: 使用 git-clone 任务
2. **镜像构建**: 使用 Kaniko 构建容器镜像
3. **镜像推送**: 推送到容器镜像仓库
4. **应用部署**: ArgoCD 自动同步部署

## 📊 监控和日志

### 应用监控

- 健康检查端点: `/health`
- 请求日志记录
- 错误追踪和报告
- 性能指标收集

### 安全特性

- 安全响应头
- 非 root 用户运行
- 资源限制配置
- 依赖安全扫描

## 🔍 故障排查

常见问题和解决方案请参考 [故障排查指南](TROUBLESHOOTING.md)。

## 📚 最佳实践

完整的 GitOps 最佳实践请参考 [GitOps 指南](GITOPS-GUIDE.md)。

## 🤝 贡献指南

1. Fork 项目
2. 创建特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add amazing feature'`)
4. 推送分支 (`git push origin feature/amazing-feature`)
5. 创建 Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件。

## 🙏 致谢

- [FastAPI](https://fastapi.tiangolo.com/) - 现代化的 Python Web 框架
- [Tekton](https://tekton.dev/) - Kubernetes 原生 CI/CD
- [ArgoCD](https://argo-cd.readthedocs.io/) - GitOps 持续部署
- [UV](https://github.com/astral-sh/uv) - 快速 Python 包管理器