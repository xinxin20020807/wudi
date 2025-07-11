# Tekton Workspace 存储方案详解

## 问题分析：为什么 emptyDir 无法在 Task 间传递数据？

### Tekton 任务执行模型

在 Tekton 中：
- **每个 Task 运行在独立的 Pod 中**
- **emptyDir 只在单个 Pod 内的容器间共享**
- **不同 Pod 间无法通过 emptyDir 共享数据**

```
Pipeline 执行流程：
┌─────────────────┐    ┌─────────────────┐
│   git-clone     │    │  build-and-push │
│   (Pod A)       │    │   (Pod B)       │
│                 │    │                 │
│ emptyDir: {}    │ ❌ │ emptyDir: {}    │
│ /workspace/src  │    │ /workspace/src  │
└─────────────────┘    └─────────────────┘
     独立存储              独立存储
```

### 当前问题症状

```bash
# git-clone 任务成功克隆代码
$ ls -la /workspace/source/
total 24
drwxrwxrwx    3 root     root          4096 Jul 11 15:09 .
drwxrwxrwx    3 root     root          4096 Jul 11 15:09 ..
-rw-r--r--    1 root     root           123 Jul 11 15:09 Dockerfile
-rw-r--r--    1 root     root           456 Jul 11 15:09 main.py

# build-and-push 任务看到空目录
$ ls -la /workspace/source/
total 8
drwxrwxrwx    2 root     root          4096 Jul 11 15:09 .
drwxrwxrwx    3 root     root          4096 Jul 11 15:09 ..
```

## 解决方案对比

### 方案1：PVC (推荐)

#### 优势
✅ **数据持久化**：在 Task 间可靠传递数据  
✅ **性能稳定**：基于持久存储，读写性能可预测  
✅ **容量可控**：可以指定存储大小  
✅ **数据安全**：即使 Pod 重启，数据仍然存在  

#### 配置示例
```yaml
workspaces:
  - name: shared-data
    volumeClaimTemplate:
      metadata:
        name: "workspace-$(context.pipelineRun.name)"
      spec:
        accessModes:
          - ReadWriteOnce
        storageClassName: "ebs-ssd"
        resources:
          requests:
            storage: 10Gi
```

#### 工作原理
```
Pipeline 执行流程：
┌─────────────────┐    ┌─────────────────┐
│   git-clone     │    │  build-and-push │
│   (Pod A)       │    │   (Pod B)       │
│                 │    │                 │
│     PVC         │ ✅ │     PVC         │
│ /workspace/src  │◄──►│ /workspace/src  │
└─────────────────┘    └─────────────────┘
       同一个持久卷
```

### 方案2：emptyDir (不适用于多Task)

#### 限制
❌ **无法跨Pod**：每个Task独立的emptyDir  
❌ **数据丢失**：Pod结束后数据消失  
❌ **容量限制**：受节点临时存储限制  

#### 适用场景
- 单个Task内的临时存储
- 同一Pod内多容器间数据共享
- 缓存和临时文件

### 方案3：hostPath (不推荐)

#### 问题
❌ **安全风险**：直接访问宿主机文件系统  
❌ **调度限制**：必须在同一节点运行  
❌ **权限复杂**：需要复杂的权限管理  

## 实际测试验证

### 测试 emptyDir 行为

```yaml
# 添加调试Task验证emptyDir行为
- name: debug-emptydir
  taskSpec:
    workspaces:
      - name: source
    steps:
      - name: check-workspace
        image: uhub.service.ucloud.cn/base-images/alpine:latest
        script: |
          echo "=== EmptyDir Debug ==="
          echo "Workspace path: $(workspaces.source.path)"
          echo "Mount info:"
          mount | grep $(workspaces.source.path)
          echo "Directory contents:"
          ls -la $(workspaces.source.path)
          echo "Filesystem info:"
          df -h $(workspaces.source.path)
  workspaces:
    - name: source
      workspace: shared-data
  runAfter:
    - git-clone
```

### 测试 PVC 行为

```yaml
# 使用PVC配置运行相同测试
workspaces:
  - name: shared-data
    volumeClaimTemplate:
      spec:
        accessModes: [ReadWriteOnce]
        resources:
          requests:
            storage: 5Gi
```

## 迁移步骤

### 步骤1：备份当前配置
```bash
cp pipelinerun.yaml pipelinerun-emptydir-backup.yaml
```

### 步骤2：使用PVC配置
```bash
# 使用新的PVC配置
kubectl apply -f pipelinerun-pvc.yaml
```

### 步骤3：验证数据传递
```bash
# 检查pipeline运行状态
kubectl get pipelinerun -n pipelines-as-code

# 查看git-clone任务日志
kubectl logs -f <pipelinerun-name>-git-clone-pod -n pipelines-as-code

# 查看build任务日志
kubectl logs -f <pipelinerun-name>-build-and-push-pod -n pipelines-as-code
```

## 性能优化建议

### 1. 存储类选择
```yaml
# 高性能SSD存储
storageClassName: "ebs-ssd"  # AWS
storageClassName: "pd-ssd"   # GCP
storageClassName: "managed-premium"  # Azure
```

### 2. 容量规划
```yaml
# 根据项目大小调整
resources:
  requests:
    storage: 5Gi   # 小项目
    storage: 20Gi  # 大项目
    storage: 50Gi  # 包含大量依赖的项目
```

### 3. 访问模式
```yaml
# 单节点访问（推荐）
accessModes:
  - ReadWriteOnce

# 多节点访问（如果需要）
accessModes:
  - ReadWriteMany
```

## 故障排除

### 常见错误1：PVC创建失败
```bash
# 检查存储类
kubectl get storageclass

# 检查PVC状态
kubectl get pvc -n pipelines-as-code

# 查看PVC事件
kubectl describe pvc <pvc-name> -n pipelines-as-code
```

### 常见错误2：权限问题
```yaml
# 添加适当的安全上下文
podTemplate:
  securityContext:
    runAsUser: 0
    fsGroup: 0
```

### 常见错误3：存储不足
```bash
# 检查节点存储
kubectl top node

# 检查PVC使用情况
kubectl exec -it <pod-name> -- df -h
```

## 最佳实践总结

1. **使用PVC进行Task间数据传递**
2. **为PVC设置动态名称避免冲突**
3. **选择合适的存储类和容量**
4. **设置适当的清理策略**
5. **监控存储使用情况**
6. **在开发环境可以使用较小的存储容量**
7. **生产环境建议使用高性能存储类**

## 结论

**emptyDir 确实无法在 Tekton 的不同 Task 间传递数据**，这是 Tekton 架构的设计特点。每个 Task 运行在独立的 Pod 中，emptyDir 只在单个 Pod 内有效。

**解决方案**：使用 PVC (PersistentVolumeClaim) 来实现 Task 间的数据持久化和传递。

**推荐配置**：使用 `pipelinerun-pvc.yaml` 中的配置，它提供了可靠的数据传递机制。