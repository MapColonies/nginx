#!/bin/bash
set -euo pipefail

README="../README.md"
VALUES_MD="../values.md"
START_MARKER="<!-- HELM_DOCS_START -->"
END_MARKER="<!-- HELM_DOCS_END -->"

# Check if helm-docs is installed
if ! command -v helm-docs &>/dev/null; then
    echo "helm-docs could not be found. Installing it..."
    go install github.com/norwoodj/helm-docs/cmd/helm-docs@latest
fi

# Navigate to the charts directory
cd ../../helm

helm-docs --chart-search-root="." --output-file=../values.md

echo "Helm documentation updated successfully!"

# Check if the values.md file was generated
if [ ! -f "$VALUES_MD" ]; then
    echo "Error: $VALUES_MD file not found!"
    exit 1
fi

# Extract only the table content (lines starting with '|')
TABLE_CONTENT=$(sed -n '/^|/p' "$VALUES_MD")

# Check if the README.md contains the markers
if grep -q "$START_MARKER" "$README"; then
    # Replace content between markers in README.md with the table content
    sed -i.bak "/$START_MARKER/,/$END_MARKER/{/$START_MARKER/{p; a $TABLE_CONTENT
        };/$END_MARKER/p; d}" "$README"

    echo "Helm documentation successfully inserted into README.md!"
else
    echo "Error: Markers not found in $README. Please ensure HELM_DOCS_START and HELM_DOCS_END are present."
    exit 1
fi
