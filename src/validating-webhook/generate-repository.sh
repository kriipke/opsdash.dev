#!/bin/bash
# generate_validating_webhook_repo.sh
# This script creates a repository structure and sample files for a validating admission webhook.
# The webhook enforces that when ociBuild.taggingStrategy is "custom", ociBuild.customTag must be provided.

# Create base directory and subdirectories
mkdir -p validating-webhook/manifests

#########################
# Create Dockerfile
#########################
cat << 'EOF' > validating-webhook/Dockerfile
FROM python:3.9-slim

WORKDIR /app

# Install Python dependencies
COPY requirements.txt requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copy the webhook application code
COPY app.py app.py

# Expose port 443 (HTTPS)
EXPOSE 443

# Run the webhook server using gunicorn for production readiness.
CMD ["gunicorn", "--bind", "0.0.0.0:443", "app:app"]
EOF

#########################
# Create requirements.txt
#########################
cat << 'EOF' > validating-webhook/requirements.txt
Flask==2.2.2
gunicorn==20.1.0
EOF

#########################
# Create app.py (Webhook Server)
#########################
cat << 'EOF' > validating-webhook/app.py
from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route('/validate', methods=['POST'])
def validate():
    admission_review = request.get_json()
    # Extract the UID from the incoming AdmissionReview request.
    uid = admission_review.get("request", {}).get("uid")
    
    # Default allow is true.
    allowed = True
    message = ""

    # Get the object under review.
    obj = admission_review.get("request", {}).get("object", {})

    # Navigate into the spec to locate ociBuild.
    spec = obj.get("spec", {})
    oci_build = spec.get("ociBuild", {})

    # If taggingStrategy is "custom", enforce that customTag is provided.
    if oci_build.get("taggingStrategy") == "custom":
        custom_tag = oci_build.get("customTag")
        if not custom_tag:
            allowed = False
            message = "Validation failed: When taggingStrategy is 'custom', customTag must be provided in ociBuild."

    # Build the AdmissionReview response.
    response = {
        "apiVersion": "admission.k8s.io/v1",
        "kind": "AdmissionReview",
        "response": {
            "uid": uid,
            "allowed": allowed,
        }
    }
    
    # If the request is denied, include a status message.
    if not allowed:
        response["response"]["status"] = {
            "message": message,
            "code": 400
        }
    
    return jsonify(response)

if __name__ == '__main__':
    # In production, serve over TLS with valid certificates.
    # Replace 'server.crt' and 'server.key' with your certificate and key files.
    app.run(host="0.0.0.0", port=443, ssl_context=('server.crt', 'server.key'))
EOF

#########################
# Create Kubernetes manifests
#########################

# Deployment manifest
cat << 'EOF' > validating-webhook/manifests/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: validating-webhook
  labels:
    app: validating-webhook
spec:
  replicas: 1
  selector:
    matchLabels:
      app: validating-webhook
  template:
    metadata:
      labels:
        app: validating-webhook
    spec:
      containers:
        - name: validating-webhook
          image: your-docker-repo/validating-webhook:latest
          ports:
            - containerPort: 443
EOF

# Service manifest
cat << 'EOF' > validating-webhook/manifests/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: validating-webhook-service
spec:
  selector:
    app: validating-webhook
  ports:
    - protocol: TCP
      port: 443
      targetPort: 443
EOF

# ValidatingWebhookConfiguration manifest
cat << 'EOF' > validating-webhook/manifests/webhook-configuration.yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: cipipeline-validating-webhook
webhooks:
  - name: validating-webhook.opsdash.dev
    clientConfig:
      service:
        name: validating-webhook-service
        namespace: default
        path: "/validate"
      caBundle: <base64-encoded-ca-cert>
    rules:
      - apiGroups:
          - opsdash.dev
        apiVersions:
          - v1alpha1
        operations:
          - CREATE
          - UPDATE
        resources:
          - cipipelines
    admissionReviewVersions: ["v1", "v1beta1"]
    sideEffects: None
EOF

#########################
# Create README.md
#########################
cat << 'EOF' > validating-webhook/README.md
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
EOF

echo "Repository structure generated in the 'validating-webhook' directory."

