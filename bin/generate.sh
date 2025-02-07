#!/bin/bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Bootstrapping the Operator Project using Kubebuilder
# This script will:
# 1. Verify that required tools (kubebuilder and go) are installed.
# 2. Initialize a new operator project with the specified domain and repo.
# 3. Scaffold a new API for the CIPipeline resource.
# -----------------------------------------------------------------------------

# Define your project settings
DOMAIN="ci.example.com"
REPO="github.com/yourusername/ci-operator"  # Change this to your repository path
GROUP="ci"
VERSION="v1alpha1"
KIND="CIPipeline"

# Check for required commands
command -v kubebuilder >/dev/null 2>&1 || { echo >&2 "kubebuilder is not installed. Please install kubebuilder and try again."; exit 1; }
command -v go >/dev/null 2>&1 || { echo >&2 "go is not installed. Please install Go and try again."; exit 1; }

echo "Bootstrapping the operator project..."

# Initialize the Kubebuilder project
echo "Initializing project with domain '${DOMAIN}' and repository '${REPO}'"
kubebuilder init --domain "$DOMAIN" --repo "$REPO"

# Create the API for the CIPipeline custom resource
echo "Creating API for ${KIND} (Group: ${GROUP}, Version: ${VERSION})"
kubebuilder create api --group "$GROUP" --version "$VERSION" --kind "$KIND" --resource --controller

echo "Operator project bootstrapped successfully!"
