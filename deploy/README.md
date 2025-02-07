Below is a heavily documented version of the CIPipeline CustomResourceDefinition (CRD). This CRD is used to define a Continuous Integration (CI) pipeline within Kubernetes. It specifies all the configuration needed to build a container image from source code, including:

- **Source Repository:**  
  Defines where the source code is located (repository URL and branch) and how to authenticate to it (using inline Vault credentials via the **externalSecret** field or by referencing an existing Kubernetes secret via the **existingSecret** field).

- **CI System:**  
  Specifies which CI system will be used (e.g. Jenkins, GitHub Actions, GitLab CI, or Azure Pipelines).

- **Triggers:**  
  Defines which events (like a push or pull request) and branch filters will trigger the pipeline.

- **Pre-Build Steps:**  
  These are steps that validate and prepare the source code prior to building the container image. They include:
  - **Linters:** For static code analysis.
  - **Code Reviews:** Which may be performed by a human or an LLM tool.
  - **Custom Steps:** For arbitrary shell command execution.
  - **Secret Scans:** For detecting secrets embedded in the code.

- **OCI Build:**  
  Contains the configuration for building the container image. It includes:
  - The Dockerfile path,
  - The build context,
  - A tagging strategy (e.g. using the Git commit, semantic versioning, or a custom tag).  
  If a custom tag is required (i.e. if the tagging strategy is set to `"custom"`), a validating webhook is expected to enforce that the **customTag** field is provided.

- **OCI Registry:**  
  Contains the configuration for pushing the built image to a container registry. Credentials for registry access are defined similarly to the repository credentials.

- **Notifications:**  
  Contains configuration for notifying users (via a webhook URL or email) when pipeline events occur.

### Detailed Explanation

1. **Top-Level CRD Fields:**
   - **apiVersion, kind, metadata:**  
     Standard Kubernetes fields. The metadata section includes an option to preserve unknown fields (such as user-defined labels and annotations).
     
   - **spec.group, spec.scope, spec.names:**  
     Define the group (`opsdash.dev`), namespace scope, and naming conventions (plural, singular, kind, short names) for CIPipeline objects.

2. **Components/Schemas Section:**
   - **SecretSource:**  
     This schema provides the configuration for sourcing credentials from HashiCorp Vault. It supports two methods:
     - **Inline Credentials (authCredentials):** Credentials are provided directly within the resource.
     - **Existing Secret (existingSecret):** A reference to a Kubernetes Secret that holds the credentials.
     
   - **CodeReview:**  
     Defines the parameters for a code review step. It allows the specification of a reviewer type (human or LLM) and a reviewer identifier (e.g. an email or tool name).
     
   - **Linter:**  
     Specifies a linting step. It includes the linter tool name, configuration file path, and file patterns to scan.
     
   - **SecretScan:**  
     Configures a tool to scan the source code for embedded secrets. It includes the tool name, configuration file, and file patterns.
     
   - **CustomStep:**  
     Defines a custom execution step, allowing for arbitrary commands to be run in a container environment. It requires both a command and a container image. It can also specify success criteria (expected exit status and output matching a regular expression).
     
   - **Repository:**  
     Describes how to access the source repository. This includes the repository URL, branch, and the method for providing credentials (either inline via externalSecret or by referencing an existing secret).
     
   - **CIPipeline (spec):**  
     The main specification for a CI pipeline. It is composed of:
     - **srcRepository:** Repository configuration.
     - **ciSystem:** Specifies which CI system to use (with allowed values such as jenkins, github, gitlab, azure).
     - **triggers:** Configuration for event-based triggers (event type and branch filter).
     - **Pre-Build Steps:**  
       Arrays of steps (linters, codeReviews, customSteps, secretScans) to be executed before building the container image.
     - **ociBuild:**  
       Configuration for building the container image. It specifies the Dockerfile path, build context, and tagging strategy (with an optional custom tag when needed).
     - **ociRegistry:**  
       Contains details for pushing the built image to a registry. Credentials are provided similarly to the repository configuration.
     - **notifications:**  
       Contains configuration for sending notifications (via webhook and email) on pipeline events.

3. **Validation & Enforcement:**
   - Many fields include detailed descriptions and constraints (such as enum values) to guide users.
   - Conditional requirements (e.g. providing customTag if taggingStrategy is "custom") are documented; actual enforcement is expected to be performed via a validating admission webhook.

This fully documented CIPipeline CRD should serve as a comprehensive specification for managing CI pipelines in your environment. Feel free to adjust the comments or descriptions as needed for your operational and documentation requirements. Happy deploying!
