#!/bin/bash
set -euo pipefail

# Check if helm-docs is installed
if ! command -v helm-docs &>/dev/null; then
    echo "helm-docs could not be found. Installing it..."
    go install github.com/norwoodj/helm-docs/cmd/helm-docs@latest
fi

# Navigate to the charts directory
cd ../../helm

# Generate the helm-docs output
echo "Generating helm-docs output..."
helm_docs_output=$(helm-docs --chart-search-root="." --template-files=VALUES.md.gotmpl)

# Read the existing README.md
readme_file="../README.md"
if [ ! -f "$readme_file" ]; then
    echo "README.md not found!"
    exit 1
fi

# Replace the content between the helm-docs markers
echo "Updating README.md with helm-docs output..."
awk -v new_content="$helm_docs_output" '
    BEGIN {output = ""}
    /<!-- helm-docs-start -->/ {output = output $0 "\n" new_content "\n"; skip = 1; next}
    /<!-- helm-docs-end -->/ {skip = 0}
    !skip {output = output $0 "\n"}
    END {print output}
' "$readme_file" > temp_readme.md

# Replace the old README.md with the updated one
mv temp_readme.md "$readme_file"

echo "Helm documentation updated successfully!"
