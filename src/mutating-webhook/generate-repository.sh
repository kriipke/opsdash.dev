#!/bin/bash
# generate_repo.sh
# This script creates the repository structure and sample files for the mutating webhook.

# Create base directory and subdirectories
mkdir -p mutating-webhook/manifests

#########################
# Create Dockerfile
#########################
cat << 'EOF' > mutating-webhook/Dockerfile
FROM python:3.9-slim

WORKDIR /app

# Install Python dependencies
COPY requirements.txt requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copy the webhook application
COPY app.py app.py

# Expose port 443 (HTTPS)
EXPOSE 443

# Run the webhook server using gunicorn (for production, consider tuning parameters)
CMD ["gunicorn", "--bind", "0.0.0.0:443", "app:app"]
EOF

#########################
# Create requirements.txt
#########################
cat << 'EOF' > mutating-webhook/requirements.txt
Flask==2.2.2
gunicorn==20.1.0
EOF

#########################
# Create app.py (Webhook Server)
#########################
cat << 'EOF' > mutating-webhook/app.py
from flask import Flask, request, jsonify
import base64
import json

app = Flask(__name__)

def mutate_pipeline(resource):
    # Remove the unified preBuildSteps array and redistribute its items
    spec = resource.get("spec", {})
    pre_build_steps = spec.pop("preBuildSteps", [])
    linters = []
    code_reviews = []
    custom_steps = []
    secret_scans = []
    job_number = 1

    for step in pre_build_steps:
        step["jobNumber"] = job_number
        job_number += 1
        step_type = step.get("type")
        if step_type == "Linter":
            linters.append(step)
        elif step_type == "CodeReview":
            code_reviews.append(step)
        elif step_type == "CustomStep":
            custom_steps.append(step)
        elif step_type == "SecretScan":
            secret_scans.append(step)

    if linters:
        spec["linters"] = linters
    if code_reviews:
        spec["codeReviews"] = code_reviews
    if custom_steps:
        spec["customSteps"] = custom_steps
    if secret_scans:
        spec["secretScans"] = secret_scans

    resource["spec"] = spec
    return resource

@app.route('/mutate', methods=['POST'])
def mutate():
    admission_review = request.get_json()
    uid = admission_review.get("request", {}).get("uid")
    resource = admission_review.get("request", {}).get("object", {})

    # Perform the mutation
    mutated_resource = mutate_pipeline(resource)

    # Log the mutated resource for debugging purposes
    app.logger.info("Mutated resource: %s", json.dumps(mutated_resource, indent=2))

    # In a real webhook, you would calculate and return a JSONPatch.
    # For simplicity, we return an empty patch and assume the webhook server applies the changes.
    response = {
        "apiVersion": "admission.k8s.io/v1",
        "kind": "AdmissionReview",
        "response": {
            "uid": uid,
            "allowed": True,
            "patchType": "JSONPatch",
            "patch": base64.b64encode(b'[]').decode('utf-8')
        }
    }
    return jsonify(response)

if __name__ == '__main__':
    # For production, serve over HTTPS with valid certificates.
    # Replace 'server.crt' and 'server.key' with your certificate and key files.
    app.run(host='0.0.0.0', port=443, ssl_context=('server.crt', 'server.key'))
EOF

#########################
# Create Kubernetes manifests
#########################

# Deployment manifest
cat << 'EOF' > mutating-webhook/manifests/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mutating-webhook
  labels:
    app: mutating-webhook
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mutating-webhook
  template:
    metadata:
      labels:
        app: mutating-webhook
    spec:
      containers:
        - name: mutating-webhook
          image: your-docker-repo/mutating-webhook:latest
          ports:
            - containerPort: 443
EOF

# Service manifest
cat << 'EOF' > mutating-webhook/manifests/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: mutating-webhook-service
spec:
  selector:
    app: mutating-webhook
  ports:
    - protocol: TCP
      port: 443
      targetPort: 443
EOF

# MutatingWebhookConfiguration manifest
cat << 'EOF' > mutating-webhook/manifests/webhook-configuration.yaml
apiVersion: admissionregistration.k8s.io/v1
kind: MutatingWebhookConfiguration
metadata:
  name: cipipeline-mutating-webhook
webhooks:
  - name: mutating-webhook.opsdash.dev
    clientConfig:
      service:
        name: mutating-webhook-service
        namespace: default
        path: "/mutate"
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
cat << 'EOF' > mutating-webhook/README.md
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
EOF

echo "Repository structure generated in the 'mutating-webhook' directory."

