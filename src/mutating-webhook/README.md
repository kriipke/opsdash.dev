# Mutating Webhook for CIPipeline

This repository contains the implementation of a mutating webhook that transforms the 'preBuildSteps'
field in CIPipeline custom resources into separate arrays (such as 'linters', 'codeReviews', 'customSteps',
and 'secretScans').

## Repository Structure

- **app.py**: Flask application implementing the mutating webhook.
- **Dockerfile**: Container build instructions.
- **requirements.txt**: Python dependencies.
- **manifests/**: Kubernetes manifests for Deployment, Service, and MutatingWebhookConfiguration.
- **README.md**: This file.

## Running Locally

1. Install dependencies:
   \`\`\`
   pip install -r requirements.txt
   \`\`\`

2. Run the webhook:
   \`\`\`
   python app.py
   \`\`\`
   *(Note: For testing locally, you can generate self-signed certificates for TLS.)*

## Kubernetes Deployment

1. Build and push your Docker image:
   \`\`\`
   docker build -t your-docker-repo/mutating-webhook:latest .
   docker push your-docker-repo/mutating-webhook:latest
   \`\`\`

2. Apply the manifests in the \`manifests/\` directory:
   \`\`\`
   kubectl apply -f manifests/deployment.yaml
   kubectl apply -f manifests/service.yaml
   kubectl apply -f manifests/webhook-configuration.yaml
   \`\`\`

Ensure that the \`caBundle\` in the webhook configuration is replaced with your base64-encoded CA certificate.

## Notes

- The mutating webhook inspects the unified \`preBuildSteps\` array in a CIPipeline resource and
  redistributes each step into a separate array based on its \`type\` field.
- The webhook logs the mutated resource for debugging. In production, the webhook should return a proper
  JSONPatch if further processing is required.
