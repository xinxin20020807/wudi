# GitOps CI/CD 最佳实践指南

## 概述

本项目使用 Tekton + Pipelines as Code + ArgoCD 实现完整的 GitOps CI/CD 流程。

## 架构组件

### 1. Tekton Pipelines
- **git-clone**: 克隆源代码
- **kaniko-build**: 构建和推送容器镜像
- **deploy**: 更新部署配置

### 2. Pipelines as Code (PAC)
- 基于 Git 事件触发 Pipeline
- 支持 PR 和 Push 事件
- 配置文件存储在 `.tekton/` 目录

### 3. ArgoCD
- 监控 Git 仓库变化
- 自动同步应用状态
- 提供可视化部署界面

## 工作流程

```mermaid
graph LR
    A[代码提交] --> B[PAC 触发]
    B --> C[Git Clone]
    C --> D[构建镜像]
    D --> E[推送镜像]
    E --> F[更新配置]
    F --> G[ArgoCD 同步]
    G --> H[应用部署]
```

## 配置文件结构

```
.tekton/
├── pipeline.yaml          # Pipeline 定义
├── pipelinerun.yaml       # PipelineRun 模板
└── tasks/
    ├── git-clone.yaml      # Git 克隆任务
    └── kaniko-build.yaml   # 镜像构建任务
```

## 关键配置

### 1. Pipeline 配置

```yaml
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: wudi-pipeline
spec:
  params:
    - name: repo-url
    - name: revision
    - name: image-url
  workspaces:
    - name: shared-data
  tasks:
    - name: fetch-source
      taskRef:
        name: git-clone
    - name: build-image
      taskRef:
        name: kaniko-build
      runAfter: ["fetch-source"]
```

### 2. 镜像构建优化

- 使用多阶段构建减小镜像大小
- 配置缓存策略提高构建速度
- 使用国内镜像源加速依赖下载
- 实现构建重试机制

### 3. 安全最佳实践

- 使用非 root 用户运行容器
- 配置资源限制防止资源耗尽
- 使用 Secret 管理敏感信息
- 实现镜像签名和扫描

## 部署策略

### 1. 蓝绿部署
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: wudi-app
spec:
  strategy:
    blueGreen:
      activeService: wudi-active
      previewService: wudi-preview
```

### 2. 金丝雀部署
```yaml
strategy:
  canary:
    steps:
    - setWeight: 20
    - pause: {duration: 10s}
    - setWeight: 40
    - pause: {duration: 10s}
    - setWeight: 60
    - pause: {duration: 10s}
    - setWeight: 80
    - pause: {duration: 10s}
```

## 监控和可观测性

### 1. 应用监控
- 健康检查端点: `/health`
- 指标收集: Prometheus
- 日志聚合: ELK Stack
- 链路追踪: Jaeger

### 2. Pipeline 监控
- Tekton Dashboard
- Pipeline 执行历史
- 失败告警通知
- 性能指标收集

## 环境管理

### 1. 多环境配置
```
envs/
├── dev/
│   ├── kustomization.yaml
│   └── patches/
├── staging/
│   ├── kustomization.yaml
│   └── patches/
└── prod/
    ├── kustomization.yaml
    └── patches/
```

### 2. 配置管理
- 使用 ConfigMap 管理应用配置
- 使用 Secret 管理敏感信息
- 环境特定的配置覆盖
- 配置版本控制

## 故障恢复

### 1. 自动回滚
```yaml
spec:
  revisionHistoryLimit: 10
  strategy:
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
```

### 2. 备份策略
- 定期备份配置文件
- 数据库备份和恢复
- 镜像版本管理
- 灾难恢复计划

## 性能优化

### 1. 构建优化
- 使用构建缓存
- 并行构建任务
- 增量构建策略
- 依赖缓存管理

### 2. 部署优化
- 预热容器镜像
- 资源预分配
- 健康检查优化
- 启动时间优化

## 安全检查清单

- [ ] 容器镜像安全扫描
- [ ] 依赖漏洞检查
- [ ] 密钥轮换策略
- [ ] 网络策略配置
- [ ] RBAC 权限控制
- [ ] 审计日志记录
- [ ] 合规性检查

## 常用命令

### 本地开发
```bash
# 启动开发服务器
make dev

# 运行测试
make test

# 构建 Docker 镜像
make docker-build

# 测试 Docker 镜像
make docker-test
```

### 部署管理
```bash
# 查看 Pipeline 状态
kubectl get pipelinerun -n pipelines-as-code

# 触发手动部署
kubectl create -f .tekton/pipelinerun.yaml

# 查看应用状态
kubectl get pods -n wudi

# 查看应用日志
kubectl logs -f deployment/wudi-app -n wudi
```

## 参考资源

- [Tekton 官方文档](https://tekton.dev/docs/)
- [Pipelines as Code 文档](https://pipelinesascode.com/)
- [ArgoCD 官方文档](https://argo-cd.readthedocs.io/)
- [GitOps 最佳实践](https://www.gitops.tech/)