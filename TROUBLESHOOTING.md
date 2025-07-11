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
