# CI/CD 故障排查指南

## 常见问题及解决方案

### 1. ModuleNotFoundError: No module named 'fastapi'

**问题描述**: 容器启动时报错找不到 Python 模块

**可能原因**:
- Docker 多阶段构建中虚拟环境路径不正确
- 依赖安装失败或不完整
- Python 路径配置错误

**解决方案**:
1. 确保 Dockerfile 中正确复制虚拟环境
2. 使用绝对路径启动应用: `/app/.venv/bin/python main.py`
3. 在生产阶段重新安装依赖确保完整性
4. 检查 pyproject.toml 中的依赖配置
5. 设置正确的文件权限: `chmod -R 755 /app/.venv/bin/`

### 2. Git Clone 任务卡住

**问题描述**: Tekton Pipeline 中 git-clone 任务卡在 "Cleaning up workspace directory..."

**可能原因**:
- 资源限制不足
- 网络连接问题
- 清理脚本执行时间过长

**解决方案**:
1. 为任务添加超时设置
2. 配置合理的资源请求和限制
3. 优化清理脚本，使用更高效的命令
4. 添加网络配置和重试机制

### 3. 依赖下载失败

**问题描述**: pip 或 uv 下载依赖时网络错误

**解决方案**:
1. 使用国内镜像源
2. 配置重试机制
3. 设置合理的超时时间
4. 限制并发下载数量

### 4. 容器健康检查失败

**问题描述**: Docker 健康检查一直失败

**解决方案**:
1. 确保健康检查端点正确实现
2. 调整健康检查的间隔和超时时间
3. 检查容器内网络配置
4. 验证应用启动时间

## 调试命令

### 本地测试
```bash
# 测试 Docker 构建和运行
make docker-test

# 查看容器日志
docker logs <container-name>

# 进入容器调试
docker exec -it <container-name> /bin/sh

# 测试依赖安装
uv pip list
```

### Kubernetes 调试
```bash
# 查看 Pod 状态
kubectl get pods -n <namespace>

# 查看 Pod 日志
kubectl logs -f <pod-name> -n <namespace>

# 查看 Pod 详细信息
kubectl describe pod <pod-name> -n <namespace>

# 进入 Pod 调试
kubectl exec -it <pod-name> -n <namespace> -- /bin/sh
```

### Tekton Pipeline 调试
```bash
# 查看 PipelineRun 状态
kubectl get pipelinerun -n <namespace>

# 查看 TaskRun 日志
kubectl logs -f <taskrun-name> -n <namespace>

# 查看 PipelineRun 详细信息
kubectl describe pipelinerun <pipelinerun-name> -n <namespace>
```

## 最佳实践

1. **多阶段构建**: 使用 Docker 多阶段构建减小镜像大小
2. **依赖锁定**: 使用 uv.lock 锁定依赖版本
3. **资源限制**: 为所有任务设置合理的资源限制
4. **超时设置**: 为长时间运行的任务设置超时
5. **健康检查**: 实现完善的健康检查机制
6. **日志记录**: 添加详细的日志输出便于调试
7. **错误处理**: 实现优雅的错误处理和重试机制
8. **安全配置**: 使用非 root 用户运行容器
9. **镜像优化**: 使用 .dockerignore 排除不必要的文件
10. **测试自动化**: 编写自动化测试验证构建和部署
