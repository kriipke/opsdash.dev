Below are several example manifests that illustrate a range of use cases for the latest CIPipeline CRD. These examples demonstrate—from the most minimal to more complex pipelines—how you can specify repository and registry credentials either by hardcoding an inline external secret definition (with Vault details) or by referencing an existing Kubernetes secret. In every case, the rule is that exactly one of `externalSecret` (which provides an inline SecretSource configuration) or `existingSecret` (which names an already existing Kubernetes secret) must be provided.

---

== Example 1: Minimal Pipeline Using Existing Secrets

In this simple example, both the source repository and the container registry credentials are provided via existing Kubernetes secrets. No pre‑build steps or triggers are defined.

```yaml
apiVersion: opsdash.dev/v1alpha1
kind: CIPipeline
metadata:
  name: minimal-pipeline
spec:
  srcRepository:
    url: "https://github.com/example/minimal-repo.git"
    branch: "main"
    # Reference an existing Kubernetes secret containing repo credentials.
    existingSecret: "minimal-repo-credentials"
  ciSystem: "github"
  ociBuild:
    dockerfile: "Dockerfile"
    context: "."
    taggingStrategy: "git-commit"
  ociRegistry:
    url: "registry.example.com"
    repository: "minimal/repo"
    # Reference an existing Kubernetes secret containing registry credentials.
    existingSecret: "minimal-registry-credentials"
```

---

== Example 2: Complex Pipeline Using Inline ExternalSecrets with Hardcoded Vault Credentials

This example illustrates a more advanced pipeline with triggers, pre‑build steps (organized into separate arrays), and notifications. Both the repository and registry credentials are provided via inline externalSecret definitions that include Vault connection details and hardcoded tokens.

```yaml
apiVersion: opsdash.dev/v1alpha1
kind: CIPipeline
metadata:
  name: complex-pipeline-inline-secrets
spec:
  srcRepository:
    url: "https://github.com/example/complex-repo.git"
    branch: "develop"
    # Inline externalSecret with hardcoded Vault credentials for the repository.
    externalSecret:
      vaultAddress: "https://vault.example.com"
      secretPath: "secret/data/complex-repo-creds"
      authMethod: "token"
      authCredentials:
        token: "s.INLINE_REPO_TOKEN"
  ciSystem: "jenkins"
  triggers:
    event: "push"
    branch: "develop"
  linters:
    - name: "eslint"
      configPath: ".eslintrc.json"
      globPatterns:
        - "src/**/*.js"
  codeReviews:
    - codeReviewerType: "human"
      codeReviewer: "reviewer@example.com"
  customSteps:
    - command: "npm run build"
      shell: "bash"
      containerImage: "node:14"
      successCriteria:
        statusCode: 0
        outputRegex: "Build succeeded"
  secretScans:
    - toolName: "trufflehog"
      globPatterns:
        - "**/*.js"
      configPath: "trufflehog-config.yml"
  ociBuild:
    dockerfile: "Dockerfile.complex"
    context: "app/"
    taggingStrategy: "semver"
  ociRegistry:
    url: "registry.example.com"
    repository: "complex/repo"
    # Inline externalSecret with hardcoded Vault credentials for the registry.
    externalSecret:
      vaultAddress: "https://vault.example.com"
      secretPath: "secret/data/complex-registry-creds"
      authMethod: "token"
      authCredentials:
        token: "s.INLINE_REGISTRY_TOKEN"
  notifications:
    webhook: "https://hooks.example.com/notify"
    email: "ops@example.com"
```

---

== Example 3: Mixed Credential Approaches

In this example, the repository credentials are provided via an existing secret while the registry credentials use an inline externalSecret that itself references an existing Kubernetes secret (via its `existingSecret` field). This mixed approach allows you to mix and match your credential sourcing methods.

```yaml
apiVersion: opsdash.dev/v1alpha1
kind: CIPipeline
metadata:
  name: mixed-credentials-pipeline
spec:
  srcRepository:
    url: "https://github.com/example/mixed-repo.git"
    branch: "main"
    # Use an existing Kubernetes secret for repository credentials.
    existingSecret: "mixed-repo-credentials"
  ciSystem: "gitlab"
  ociBuild:
    dockerfile: "Dockerfile"
    context: "."
    taggingStrategy: "custom"
    customTag: "v2.0.1"
  ociRegistry:
    url: "registry.example.com"
    repository: "mixed/repo"
    # Use an inline externalSecret that references an existing secret for the registry credentials.
    externalSecret:
      vaultAddress: "https://vault.example.com"
      secretPath: "secret/data/mixed-registry-creds"
      authMethod: "appRole"
      existingSecret: "mixed-registry-vault-secret"
```

---

== Example 4: Advanced Pipeline with Multiple Pre‑Build Steps and Advanced Triggers

This comprehensive example shows an advanced configuration that includes multiple pre‑build steps (two linters, one code review, one custom step, and one secret scan), detailed triggers (for pull requests on feature branches), and notifications. The repository credentials are specified via an inline externalSecret referencing an existing Kubernetes secret, while the registry credentials are provided by an existing secret.

```yaml
apiVersion: opsdash.dev/v1alpha1
kind: CIPipeline
metadata:
  name: advanced-pipeline
spec:
  srcRepository:
    url: "https://github.com/example/advanced-repo.git"
    branch: "feature/advanced"
    # Inline externalSecret referencing an existing secret for repository credentials.
    externalSecret:
      vaultAddress: "https://vault.example.com"
      secretPath: "secret/data/advanced-repo-creds"
      authMethod: "kubernetes"
      existingSecret: "advanced-repo-vault-secret"
  ciSystem: "azure"
  triggers:
    event: "pull_request"
    branch: "feature/*"
  linters:
    - name: "pylint"
      configPath: "pylintrc"
      globPatterns:
        - "src/**/*.py"
    - name: "flake8"
      configPath: ".flake8"
      globPatterns:
        - "src/**/*.py"
  codeReviews:
    - codeReviewerType: "llm"
      codeReviewer: "openai-gpt"
  customSteps:
    - command: "pytest --maxfail=1"
      shell: "bash"
      containerImage: "python:3.8"
      successCriteria:
        statusCode: 0
        outputRegex: "All tests passed"
  secretScans:
    - toolName: "detect-secrets"
      globPatterns:
        - "**/*.py"
      configPath: "detect-secrets-config.yml"
  ociBuild:
    dockerfile: "Dockerfile.advanced"
    context: "build/"
    taggingStrategy: "custom"
    customTag: "v3.5.2"
  ociRegistry:
    url: "registry.advanced.com"
    repository: "advanced/repo"
    # Use an existing Kubernetes secret for registry credentials.
    existingSecret: "advanced-registry-credentials"
  notifications:
    webhook: "https://hooks.advanced.com/notify"
    email: "advanced-ops@example.com"
```

---

These examples demonstrate the flexibility of the latest CIPipeline CRD. They cover scenarios from a minimal pipeline using existing secrets to complex pipelines with multiple pre‑build steps, advanced triggers, and mixed approaches for credential sourcing. Adjust the values and configurations as needed to match your environment and operational requirements.
