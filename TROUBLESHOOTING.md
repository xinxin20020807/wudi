# Tekton + Pipelines as Code (PaC) 故障排查指南

本文档旨在帮助您诊断和解决在基于 Tekton 和 PaC 的 CI/CD 流程中可能遇到的常见问题。

## 问题：构建日志显示旧的或过时的命令

**症状**

您已经更新了代码（例如 `Dockerfile`），并将变更推送到了 Git 仓库的主分支。然而，当 CI/CD 流水线（由 PaC 触发）运行时，构建日志显示仍在执行旧的、已经被您修改或删除的命令。

**根本原因**

在纯 Tekton+PaC 环境中，这个问题通常与 Git 事件的处理和 `Repository` 自定义资源（CR）的状态有关。具体原因可能包括：

*   **`Repository` CR 未更新**：PaC 使用一个名为 `Repository` 的 CR 来追踪 Git 仓库的状态。当一个新的 commit 被推送时，PaC 控制器应该会更新这个 CR 中的状态。如果这个更新失败或延迟，PaC 在生成新的 `PipelineRun` 时可能会使用旧的 commit SHA。
*   **Webhook 事件问题**：PaC 严重依赖来自 Git 提供商（如 GitHub、GitLab）的 Webhook 事件来触发流水线。如果 Webhook 没有被正确配置、发送失败或被 PaC 控制器忽略，那么新的 commit 就不会触发任何操作。
*   **PaC 控制器缓存或故障**：PaC 控制器本身可能存在内部缓存或遇到错误，导致它使用过时的配置信息。

**解决方案：诊断并刷新 PaC 状态**

排查重点应放在检查 PaC 的核心组件和相关资源上。

1.  **检查 `Repository` CR 的状态**：

    这是最关键的一步。您需要检查 PaC 为您的 Git 仓库创建的 `Repository` CR，并确认它是否已经更新到了最新的 commit。

    ```bash
    # 替换 <YOUR_NAMESPACE> 为您的 PaC 所在的命名空间
    # 通常是 pipelines-as-code 或您安装时指定的命名空间
    kubectl get repositories -n <YOUR_NAMESPACE>

    # 检查特定 Repository CR 的详细信息
    kubectl get repository <REPOSITORY_NAME> -n <YOUR_NAMESPACE> -o yaml
    ```

    在 YAML 输出中，查找 `status.latest_commit.sha` 字段，并将其与您在 Git 仓库中的最新 commit hash 进行比较。如果不匹配，说明 PaC 没有正确地检测到新的变更。

2.  **检查 PaC 控制器的日志**：

    PaC 控制器的日志是诊断问题的金矿。您可以查看日志，寻找与 Webhook 事件处理、`Repository` CR 更新或 `PipelineRun` 生成相关的错误信息。

    ```bash
    # 找到 PaC 控制器的 Pod 名称 (通常在 pipelines-as-code 命名空间)
    kubectl get pods -n pipelines-as-code

    # 查看控制器日志
    kubectl logs -f <PAC_CONTROLLER_POD_NAME> -n pipelines-as-code
    ```

3.  **手动重新触发流水线**：

    如果 `Repository` CR 已经更新，但流水线没有自动运行，您可以尝试手动触发它。最简单的方法是向 Pull Request (PR) 添加一条特定的注释（如果您的 `pipelinerun.yaml` 中配置了 `on-comment` 触发器）。

    例如，如果您的配置是 `on-comment: "/retest"`，那么在相关的 PR 中评论 `/retest` 就会强制 PaC 重新运行测试。

## 问题：PipelineRunTimeout 错误

**症状**

当运行 `kubectl get repo -n pipelines-as-code` 时，看到 Repository 状态显示 `SUCCEEDED: False` 和 `REASON: PipelineRunTimeout`，表明流水线执行超时失败。

**根本原因**

流水线超时通常由以下原因引起：

*   **超时设置过短**：`pipelinerun.yaml` 中的 `timeouts` 配置可能不足以完成所有任务
*   **构建任务耗时过长**：Docker 镜像构建、依赖安装等步骤可能需要更多时间
*   **网络问题**：拉取基础镜像或下载依赖时网络延迟
*   **资源限制**：CPU 或内存资源不足导致任务执行缓慢

**解决方案**

1.  **检查当前超时配置**：

    ```bash
    # 查看 pipelinerun.yaml 中的超时设置
    cat .tekton/pipelinerun.yaml | grep -A 5 "timeouts:"
    ```

2.  **增加超时时间**：

    编辑 `.tekton/pipelinerun.yaml` 文件，增加 `pipeline` 和 `tasks` 的超时时间：

    ```yaml
    timeouts:
      pipeline: "30m"  # 从 10m 增加到 30m
      tasks: "15m"     # 从 5m 增加到 15m
    ```

3.  **检查具体任务执行时间**：

    ```bash
    # 查看最近的 PipelineRun 详情
    kubectl get pipelinerun -n pipelines-as-code --sort-by=.metadata.creationTimestamp

    # 查看具体 PipelineRun 的任务执行情况
    kubectl describe pipelinerun <PIPELINERUN_NAME> -n pipelines-as-code
    ```

4.  **优化构建过程**：

    *   **启用 Docker 构建缓存**：在 `kaniko-build.yaml` 中确保缓存配置正确
    *   **使用更小的基础镜像**：如 `python:3.10-slim` 而不是 `python:3.10`
    *   **优化依赖安装**：使用 `requirements.txt` 而不是复杂的包管理工具

5.  **检查资源配置**：

    确保 PipelineRun 有足够的计算资源：

    ```yaml
    # 在 pipelinerun.yaml 中添加资源请求
    podTemplate:
      securityContext:
        runAsNonRoot: false
        runAsUser: 0
      resources:
        requests:
          memory: "1Gi"
          cpu: "500m"
        limits:
          memory: "2Gi"
          cpu: "1000m"
    ```

6.  **手动重新触发**：

    如果调整了超时配置，可以通过以下方式重新触发流水线：

    ```bash
    # 方法1：在 PR 中添加注释（如果配置了 on-comment 触发器）
    # 在 GitHub PR 中评论：/retest

    # 方法2：推送新的 commit 触发流水线
     git commit --allow-empty -m "retrigger pipeline"
     git push origin main
     ```

## 问题：Git 连接 GitHub 超时

**症状**

当执行 Git 操作时出现类似以下错误：
```
fatal: unable to access 'https://github.com/xinxin20020807/wudi/': Failed to connect to github.com port 443 after 129581 ms: Operation timed out
```

**根本原因**

这个问题通常由网络连接问题引起：

*   **网络防火墙限制**：企业网络或本地防火墙阻止了对 GitHub 的访问
*   **DNS 解析问题**：无法正确解析 github.com 域名
*   **代理配置问题**：需要通过代理访问互联网但 Git 配置不正确
*   **网络不稳定**：网络连接不稳定导致超时
*   **GitHub 服务问题**：GitHub 服务暂时不可用（较少见）

**解决方案**

1.  **检查网络连接**：

    ```bash
    # 测试是否能访问 GitHub
    ping github.com
    
    # 测试 HTTPS 连接
    curl -I https://github.com
    
    # 检查 DNS 解析
    nslookup github.com
    ```

2.  **配置 Git 代理**（如果需要通过代理访问）：

    ```bash
    # 设置 HTTP 代理
    git config --global http.proxy http://proxy.company.com:8080
    git config --global https.proxy https://proxy.company.com:8080
    
    # 如果代理需要认证
    git config --global http.proxy http://username:password@proxy.company.com:8080
    
    # 取消代理设置
    git config --global --unset http.proxy
    git config --global --unset https.proxy
    ```

3.  **使用 SSH 替代 HTTPS**：

    ```bash
    # 生成 SSH 密钥（如果还没有）
    ssh-keygen -t ed25519 -C "your_email@example.com"
    
    # 将公钥添加到 GitHub 账户
    cat ~/.ssh/id_ed25519.pub
    
    # 测试 SSH 连接
    ssh -T git@github.com
    
    # 修改远程仓库 URL 为 SSH
     git remote set-url origin git@github.com:xinxin20020807/wudi.git
     ```

## SSH 配置和故障排查

### SSH 密钥配置

#### 1. 生成 SSH 密钥
```bash
# 生成 ed25519 类型的 SSH 密钥（推荐）
ssh-keygen -t ed25519 -f ~/.ssh/tekton_key -N ""

# 或者生成 RSA 密钥（兼容性更好）
ssh-keygen -t rsa -b 4096 -f ~/.ssh/tekton_rsa_key -N ""
```

#### 2. 添加公钥到 Git 服务

**GitHub**:
1. 复制公钥内容：`cat ~/.ssh/tekton_key.pub`
2. 访问 GitHub Settings > SSH and GPG keys
3. 点击 "New SSH key"，粘贴公钥内容

**GitLab**:
1. 复制公钥内容：`cat ~/.ssh/tekton_key.pub`
2. 访问 GitLab User Settings > SSH Keys
3. 粘贴公钥内容并保存

#### 3. 创建 Kubernetes Secret
```bash
# 创建包含 SSH 密钥的 Secret
kubectl create secret generic ssh-key \
  --from-file=id_ed25519=~/.ssh/tekton_key \
  --from-file=id_ed25519.pub=~/.ssh/tekton_key.pub

# 验证 Secret 创建成功
kubectl get secret ssh-key -o yaml
```

#### 4. 在 PipelineRun 中使用 SSH
```yaml
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  name: my-pipeline-run
spec:
  pipelineRef:
    name: my-pipeline
  workspaces:
    - name: shared-data
      volumeClaimTemplate:
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 1Gi
    - name: ssh-directory
      secret:
        secretName: ssh-key
  params:
    - name: repo-url
      value: "git@github.com:username/repository.git"  # 注意使用 SSH 格式
```

### SSH 故障排查

#### 常见问题 1: SSH 密钥权限错误
**症状**: `Permissions 0644 for '/home/git/.ssh/id_ed25519' are too open`

**解决方案**:
```bash
# 检查密钥文件权限
ls -la ~/.ssh/

# 设置正确的权限
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
chmod 644 ~/.ssh/known_hosts
```

#### 常见问题 2: Host key verification failed
**症状**: `Host key verification failed`

**解决方案**:
```bash
# 手动添加主机到 known_hosts
ssh-keyscan -t rsa,ed25519 github.com >> ~/.ssh/known_hosts
ssh-keyscan -t rsa,ed25519 gitlab.com >> ~/.ssh/known_hosts

# 或者在 git clone 时跳过主机验证（不推荐用于生产环境）
export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no"
```

#### 常见问题 3: SSH 密钥未被识别
**症状**: `Permission denied (publickey)`

**解决方案**:
```bash
# 测试 SSH 连接
ssh -T git@github.com
ssh -T git@gitlab.com

# 检查 SSH agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# 列出已加载的密钥
ssh-add -l
```

#### 常见问题 4: URL 格式错误
**症状**: 仍然尝试使用 HTTPS 认证

**解决方案**:
确保使用正确的 SSH URL 格式：
- ✅ 正确：`git@github.com:username/repository.git`
- ❌ 错误：`https://github.com/username/repository.git`

### SSH 配置验证

#### 验证 SSH 配置
```bash
# 测试 GitHub SSH 连接
ssh -T git@github.com
# 期望输出：Hi username! You've successfully authenticated...

# 测试 GitLab SSH 连接
ssh -T git@gitlab.com
# 期望输出：Welcome to GitLab, @username!

# 详细调试 SSH 连接
ssh -vT git@github.com
```

#### 验证 Kubernetes Secret
```bash
# 检查 Secret 内容
kubectl get secret ssh-key -o jsonpath='{.data.id_ed25519}' | base64 -d

# 检查 Secret 是否正确挂载到 Pod
kubectl describe pod <pod-name>
```

### 最佳实践

1. **使用 ed25519 密钥类型**：更安全，性能更好
2. **为不同环境使用不同的密钥**：开发、测试、生产环境分离
3. **定期轮换 SSH 密钥**：建议每 6-12 个月更换一次
4. **限制密钥权限**：只授予必要的仓库访问权限
5. **监控 SSH 密钥使用**：定期检查 Git 服务的访问日志
6. **备份密钥**：安全地备份私钥，防止丢失
7. **使用专用的服务账户**：为 CI/CD 创建专门的 Git 账户

4.  **调整 Git 超时设置**：

    ```bash
    # 增加 HTTP 超时时间
    git config --global http.timeout 300
    
    # 增加低速限制时间
    git config --global http.lowSpeedLimit 0
    git config --global http.lowSpeedTime 999999
    ```

5.  **使用 GitHub CLI 作为替代**：

    ```bash
    # 安装 GitHub CLI（macOS）
    brew install gh
    
    # 登录 GitHub
    gh auth login
    
    # 克隆仓库
    gh repo clone xinxin20020807/wudi
    ```

6.  **检查 Tekton 中的网络配置**：

    如果问题出现在 Tekton Pipeline 中，可能需要配置网络策略或代理：

    ```yaml
    # 在 git-clone.yaml 中添加代理环境变量
    env:
      - name: HTTP_PROXY
        value: "http://proxy.company.com:8080"
      - name: HTTPS_PROXY
        value: "https://proxy.company.com:8080"
      - name: NO_PROXY
        value: "localhost,127.0.0.1,.local"
    ```

7.  **临时解决方案**：

    ```bash
    # 使用 GitHub 镜像站点（中国大陆用户）
    git config --global url."https://github.com.cnpmjs.org/".insteadOf "https://github.com/"
    
    # 恢复原始设置
    git config --global --unset url."https://github.com.cnpmjs.org/".insteadOf
    ```
