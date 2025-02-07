Below is one way to model your CI pipeline as a Kubernetes-native custom resource. In this design, we define a **CIPipeline** CRD that captures the desired state for building and pushing container images while supporting optional pre-build steps (code reviews, security scans, secret checks, etc.) as well as the choice of underlying CI/CD system (Jenkins, GitHub Actions, GitLab CI/CD, Tekton, Argo Workflows, etc.).

The controller you build will watch for these CRs and translate them into a concrete pipeline definition in the selected system. The following example demonstrates how you can leverage Kubernetes’ declarative style to describe your build process—and how to tie in external secret management (via an external secrets operator) for registry credentials.

---

## 1. CRD Specification

Below is the YAML for a sample CustomResourceDefinition. This CRD defines a `CIPipeline` resource in the group `cicd.example.com`. Its schema covers:

- **`ciTool`** – The target CI/CD system (e.g., `jenkins`, `github-actions`).
- **`triggers`** – Events that should trigger the pipeline (on push, on pull request, or even on a cron schedule).
- **`preBuildSteps`** – An array of steps (like code review, security scans, secret checks, etc.) that run before the actual build.
- **`build`** – Instructions on how to build the container image: build context, Dockerfile path, image name, and registry configuration (including an external secret reference for credentials).
- **`taggingStrategy`** – How to tag the built image. Options include using the Git commit, enforcing Semantic Versioning (SemVer), or a custom strategy.
- **`notifications`** – Optional notifications (e.g., Slack, email) for pipeline events.

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: cipipelines.cicd.example.com
spec:
  group: cicd.example.com
  names:
    kind: CIPipeline
    plural: cipipelines
    singular: cipipeline
    shortNames:
      - cicp
  scope: Namespaced
  versions:
    - name: v1alpha1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                ciTool:
                  type: string
                  description: "The CI/CD system to use for pipeline generation."
                  enum:
                    - jenkins
                    - github-actions
                    - gitlab-ci
                    - tekton
                    - argo-workflows
                triggers:
                  type: object
                  properties:
                    onPush:
                      type: boolean
                      description: "Trigger the pipeline on git push events."
                    onPullRequest:
                      type: boolean
                      description: "Trigger the pipeline on pull request events."
                    schedule:
                      type: string
                      description: "Cron expression to schedule periodic pipeline runs."
                      # Note: For brevity, no complex regex pattern is enforced here.
                preBuildSteps:
                  type: array
                  description: "Optional pre-build steps, such as code reviews or security scans."
                  items:
                    type: object
                    properties:
                      name:
                        type: string
                        description: "A unique name for the pre-build step."
                      type:
                        type: string
                        description: "The type of pre-build check."
                        enum:
                          - codeReview
                          - securityScan
                          - secretCheck
                          - sast
                          - custom
                      enabled:
                        type: boolean
                        description: "Toggle to enable or disable the step."
                      config:
                        type: object
                        description: "Additional configuration for the pre-build step."
                        additionalProperties: true
                build:
                  type: object
                  description: "Configuration for building and pushing the container image."
                  properties:
                    context:
                      type: string
                      description: "The build context directory (relative path)."
                    dockerfile:
                      type: string
                      description: "Path to the Dockerfile."
                    imageName:
                      type: string
                      description: "Full name of the container image (including registry URL)."
                    registry:
                      type: object
                      description: "Registry settings."
                      properties:
                        url:
                          type: string
                          description: "Registry URL."
                        repository:
                          type: string
                          description: "Repository name in the registry."
                        credentials:
                          type: object
                          description: "External secret configuration for registry credentials."
                          properties:
                            externalSecretRef:
                              type: string
                              description: "Reference to the external secret (managed by an external secrets operator)."
                taggingStrategy:
                  type: object
                  description: "Rules for tagging the built container image."
                  properties:
                    type:
                      type: string
                      description: "Tagging mode: use git commit hash, enforce semantic versioning, or a custom strategy."
                      enum:
                        - git-commit
                        - semver
                        - custom
                    semverEnforced:
                      type: boolean
                      description: "If true, ensure the tag follows Semantic Versioning (only applicable when type is 'semver')."
                    customTagExpression:
                      type: string
                      description: "Custom expression for generating the tag (only applicable when type is 'custom')."
                notifications:
                  type: object
                  description: "Optional notifications for pipeline events."
                  properties:
                    slack:
                      type: object
                      properties:
                        channel:
                          type: string
                          description: "Slack channel to send notifications to."
                        webhookUrl:
                          type: string
                          description: "Slack webhook URL."
                    email:
                      type: object
                      properties:
                        recipients:
                          type: array
                          description: "List of email addresses to notify."
                          items:
                            type: string
              required:
                - ciTool
                - build
```

---

## 2. Configuration Flexibility

This design is intentionally flexible:

- **CI/CD Tool Selection:**  
  The `ciTool` field lets the user pick from supported systems. The controller should map this value to the appropriate pipeline templating engine (Jenkinsfile, GitHub Actions YAML, etc.).

- **Tagging Strategy:**  
  Under `taggingStrategy`, users can specify:
  - **`git-commit`** – Use the commit hash as the image tag.
  - **`semver`** – Optionally enforce Semantic Versioning by setting `semverEnforced` to `true`.
  - **`custom`** – Use a custom tag expression (e.g., `"build-{timestamp}-{commit}"`) via `customTagExpression`.

- **External Secrets Integration:**  
  The `build.registry.credentials.externalSecretRef` field is designed to work with any secrets manager supported by the [external-secrets-operator](https://external-secrets.io/). This way, the pipeline can securely pull registry credentials at runtime.

---

## 3. Example CR Manifests

Below are two sample Custom Resource manifests—one for a **standard** CI pipeline configuration using GitHub Actions, and a second for a **complex** configuration using Jenkins.

### **Example 1: Standard CI Pipeline with GitHub Actions**

```yaml
apiVersion: cicd.example.com/v1alpha1
kind: CIPipeline
metadata:
  name: my-webservice-ci
spec:
  ciTool: github-actions
  triggers:
    onPush: true
    onPullRequest: true
  preBuildSteps:
    - name: security-scan
      type: securityScan
      enabled: true
      config:
        tool: "trivy"
        severity: "HIGH"
  build:
    context: "./"
    dockerfile: "Dockerfile"
    imageName: "registry.example.com/my-webservice"
    registry:
      url: "registry.example.com"
      repository: "my-webservice"
      credentials:
        externalSecretRef: "registry-creds"
  taggingStrategy:
    type: git-commit
  notifications:
    slack:
      channel: "#ci-alerts"
      webhookUrl: "https://hooks.slack.com/services/xxx/yyy/zzz"
```

> **Assumptions & Behavior:**  
> - The pipeline is triggered on code pushes and pull requests.  
> - A security scan using [Trivy](https://github.com/aquasecurity/trivy) is executed before the build.  
> - The built image is tagged using the Git commit hash.

---

### **Example 2: Complex Jenkins Pipeline with Custom Triggers & Tagging**

```yaml
apiVersion: cicd.example.com/v1alpha1
kind: CIPipeline
metadata:
  name: complex-jenkins-pipeline
spec:
  ciTool: jenkins
  triggers:
    onPush: false
    onPullRequest: true
    schedule: "0 2 * * *"  # Run daily at 2 AM.
  preBuildSteps:
    - name: code-review
      type: codeReview
      enabled: true
      config:
        requiredApprovals: 2
    - name: secret-check
      type: secretCheck
      enabled: true
    - name: custom-sast
      type: sast
      enabled: true
      config:
        tool: "sonarQube"
        ruleset: "security-rules"
  build:
    context: "./service"
    dockerfile: "Dockerfile.ci"
    imageName: "registry.internal/my-company/webservice"
    registry:
      url: "registry.internal"
      repository: "my-company/webservice"
      credentials:
        externalSecretRef: "internal-registry-credentials"
  taggingStrategy:
    type: custom
    customTagExpression: "build-{timestamp}-{commit}"
  notifications:
    email:
      recipients:
        - "dev-team@mycompany.com"
```

> **Assumptions & Behavior:**  
> - The pipeline is configured to trigger on pull requests and on a daily schedule.  
> - It includes multiple pre-build checks: a code review requiring at least two approvals, a secret check, and a custom SAST step using SonarQube.  
> - The image is tagged using a custom expression that combines a timestamp and commit hash.

---

## Final Thoughts

This CRD design provides a declarative way to manage your CI pipelines within Kubernetes. By exposing the key configurable parameters (CI tool selection, triggers, build details, tagging strategy, and notifications), you enable your controller to “reconcile” the desired state with the underlying CI/CD system. Furthermore, by integrating with external secret management, you keep your credentials secure and decoupled from the pipeline logic.

This approach should help you streamline operations, make pipeline management more consistent across teams, and enable a GitOps-style workflow for your CI processes. Enjoy building your pipelines!
