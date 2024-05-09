#!/bin/bash
helm registry login $ACR_URL --username $ACR_PUSH_USER --password-stdin $ACR_PUSH_TOKEN
CHART_NAME=$(cat Chart.yaml | grep name | awk '{print $2; exit}')
CHART_VERSION=$(cat Chart.yaml | grep version | awk '{print $2; exit}')
helm package --dependency-update .
helm push $CHART_NAME-$CHART_VERSION.tgz oci://$ACR_URL/helm"