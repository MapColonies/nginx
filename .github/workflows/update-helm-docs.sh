#!/bin/bash
set -euo pipefail

# Check if helm-docs is installed
if ! command -v helm-docs &>/dev/null; then
    echo "helm-docs could not be found. Installing it..."
    go install github.com/norwoodj/helm-docs/cmd/helm-docs@latest
fi

# Navigate to the charts directory
pwd
cd ../../helm

# # Run helm-docs for each chart
# for chart in */; do
#     if [ -d "$chart" ]; then
#         echo "Generating docs for $chart"
helm-docs --chart-search-root="." --template-files=VALUES.md.gotmpl --output-file=../README.md
#     fi
# done

echo "Helm documentation updated successfully!"