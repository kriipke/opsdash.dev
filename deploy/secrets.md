### Example 1: Both Repository and Registry Use an Existing Kubernetes Secret

In this manifest, both the Git repository and the container registry credentials are provided by referencing existing Kubernetes secrets.

```yaml
apiVersion: opsdash.dev/v1alpha1
kind: CIPipeline
metadata:
  name: example-using-existing-secrets
spec:
  srcRepository:
    url: "https://github.com/example/repo.git"
    branch: "main"
    # Reference an existing Kubernetes secret that contains the repo credentials.
    existingSecret: "repo-credentials-secret"
  ciSystem: "github"
  ociBuild:
    dockerfile: "Dockerfile"
    context: "."
    taggingStrategy: "git-commit"
  ociRegistry:
    url: "registry.example.com"
    repository: "example/repo"
    # Reference an existing Kubernetes secret that contains the registry credentials.
    existingSecret: "registry-credentials-secret"
```

---

### Example 2: Both Repository and Registry Use an Inline ExternalSecret with Hardcoded Credentials

Here, the inline external secret definition is used in both cases, and the required Vault connection details and authentication credentials are hardcoded directly into the manifest.

```yaml
apiVersion: opsdash.dev/v1alpha1
kind: CIPipeline
metadata:
  name: example-with-hardcoded-externalsecret
spec:
  srcRepository:
    url: "https://github.com/example/repo.git"
    branch: "main"
    # Provide an inline externalSecret with hardcoded Vault auth credentials.
    externalSecret:
      vaultAddress: "https://vault.example.com"
      secretPath: "secret/data/repo-creds"
      authMethod: "token"
      authCredentials:
        token: "s.HARDCODED_TOKEN_REPO"
  ciSystem: "github"
  ociBuild:
    dockerfile: "Dockerfile"
    context: "."
    taggingStrategy: "git-commit"
  ociRegistry:
    url: "registry.example.com"
    repository: "example/repo"
    # Provide an inline externalSecret with hardcoded Vault auth credentials.
    externalSecret:
      vaultAddress: "https://vault.example.com"
      secretPath: "secret/data/registry-creds"
      authMethod: "token"
      authCredentials:
        token: "s.HARDCODED_TOKEN_REGISTRY"
```

---

### Example 3: Both Repository and Registry Use an Inline ExternalSecret That References an Existing Secret

In this example, instead of hardcoding the credentials, the externalSecret object itself uses its new `existingSecret` property to reference an existing Kubernetes secret (within the external secret definition). This approach lets you decouple the Vault connection details from the actual secret values, which are stored externally.

```yaml
apiVersion: opsdash.dev/v1alpha1
kind: CIPipeline
metadata:
  name: example-with-internal-existingsecret
spec:
  srcRepository:
    url: "https://github.com/example/repo.git"
    branch: "main"
    # Use an inline externalSecret that references an existing secret for the credential value.
    externalSecret:
      vaultAddress: "https://vault.example.com"
      secretPath: "secret/data/repo-creds"
      authMethod: "appRole"
      # Instead of providing authCredentials inline, reference an existing Kubernetes secret.
      existingSecret: "repo-vault-secret"
  ciSystem: "jenkins"
  ociBuild:
    dockerfile: "Dockerfile"
    context: "."
    taggingStrategy: "git-commit"
  ociRegistry:
    url: "registry.example.com"
    repository: "example/repo"
    externalSecret:
      vaultAddress: "https://vault.example.com"
      secretPath: "secret/data/registry-creds"
      authMethod: "kubernetes"
      existingSecret: "registry-vault-secret"
```

---

### Example 4: Mixed Configuration – Repository Uses an Existing Secret and Registry Uses an Inline ExternalSecret

This example shows a mixed approach: the repository credentials are provided via an existing secret (top‑level), while the registry credentials are supplied inline using an externalSecret with hardcoded values.

```yaml
apiVersion: opsdash.dev/v1alpha1
kind: CIPipeline
metadata:
  name: example-mixed-configuration
spec:
  srcRepository:
    url: "https://github.com/example/repo.git"
    branch: "main"
    # Use an existing Kubernetes secret for repository credentials.
    existingSecret: "repo-credentials-secret"
  ciSystem: "gitlab"
  ociBuild:
    dockerfile: "Dockerfile"
    context: "."
    taggingStrategy: "git-commit"
  ociRegistry:
    url: "registry.example.com"
    repository: "example/repo"
    # Provide an inline externalSecret with hardcoded Vault credentials for the registry.
    externalSecret:
      vaultAddress: "https://vault.example.com"
      secretPath: "secret/data/registry-creds"
      authMethod: "token"
      authCredentials:
        token: "s.HARDCODED_TOKEN_REGISTRY"
```

---

### Summary

- **Existing Secret Usage:**  
  In Example 1, both the repository and registry sections simply reference an existing Kubernetes secret via the top‑level `existingSecret` field.

- **Inline ExternalSecret with Hardcoded Values:**  
  In Example 2, both sections use the `externalSecret` field to include the full Vault configuration and inline credentials.

- **Inline ExternalSecret Referencing an Existing Secret Internally:**  
  In Example 3, the `externalSecret` field is used, but instead of hardcoding credentials, it leverages its own `existingSecret` property to reference another Kubernetes secret that contains the credential value.

- **Mixed Configuration:**  
  Example 4 demonstrates how you might mix these approaches between the repository and registry credentials.

Each manifest respects the rule that exactly one of `externalSecret` or `existingSecret` is provided in both the `srcRepository` and `ociRegistry` sections. These examples should serve as a guide to how you can support multiple credential configuration strategies with your updated CRD. Happy deploying!