#!/bin/bash
set -euo pipefail

# Check if helm-docs is installed
if ! command -v helm-docs &>/dev/null; then
    echo "helm-docs could not be found. Installing it..."
    go install github.com/norwoodj/helm-docs/cmd/helm-docs@latest
fi

# Navigate to the charts directory
cd ../../helm

helm-docs --chart-search-root="." --output-file=../values.md

echo "Helm documentation updated successfully!"
