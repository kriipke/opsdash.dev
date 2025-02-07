# Validating Webhook for CIPipeline

This repository contains a validating webhook that intercepts create and update requests
for CIPipeline custom resources. It enforces the rule that if the ociBuild.taggingStrategy is "custom",
then ociBuild.customTag must be provided.

## Repository Structure

- **app.py**: Flask application implementing the validating webhook.
- **Dockerfile**: Container build instructions.
- **requirements.txt**: Python dependencies.
- **manifests/**: Kubernetes manifests for Deployment, Service, and ValidatingWebhookConfiguration.
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
   *(For local testing, generate self-signed certificates for TLS.)*

## Kubernetes Deployment

1. Build and push your Docker image:
   \`\`\`
   docker build -t your-docker-repo/validating-webhook:latest .
   docker push your-docker-repo/validating-webhook:latest
   \`\`\`

2. Apply the manifests in the \`manifests/\` directory:
   \`\`\`
   kubectl apply -f manifests/deployment.yaml
   kubectl apply -f manifests/service.yaml
   kubectl apply -f manifests/webhook-configuration.yaml
   \`\`\`

Ensure that the \`caBundle\` in the webhook configuration is replaced with your base64-encoded CA certificate.

## Notes

- The webhook validates that if \`ociBuild.taggingStrategy\` is "custom", then \`ociBuild.customTag\` is provided.
- Logging and error handling can be enhanced as needed for production.
