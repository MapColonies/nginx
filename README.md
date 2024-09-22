# nginx

![Version: 1.3.0](https://img.shields.io/badge/Version-1.3.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 1.0.0](https://img.shields.io/badge/AppVersion-1.0.0-informational?style=flat-square)

A Helm chart for nginx

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| additionalPodAnnotations | object | `{}` |  |
| authorization.domain | string | `"example"` |  |
| authorization.enabled | bool | `true` |  |
| authorization.url | string | `"http://localhost:8181/v1/data/http/authz/decision"` |  |
| caKey | string | `"ca.crt"` |  |
| caPath | string | `"/usr/local/share/ca-certificates"` |  |
| caSecretName | string | `""` |  |
| cloudProvider.dockerRegistryUrl | string | `"my-registry-url"` |  |
| cloudProvider.flavor | string | `"openshift"` |  |
| cloudProvider.imagePullSecretName | string | `"imagepullsecret"` |  |
| enabled | bool | `true` |  |
| env.opentelemetry.exporterEndpoint | string | `"localhost:4317"` |  |
| env.opentelemetry.parentBased | string | `"false"` |  |
| env.opentelemetry.ratio | float | `0.1` |  |
| env.opentelemetry.samplerMethod | string | `"AlwaysOff"` |  |
| env.opentelemetry.serviceName | string | `"nginx"` |  |
| environment | string | `"development"` |  |
| extraVolumeMounts | list | `[]` |  |
| extraVolumes | list | `[]` |  |
| fullnameOverride | string | `""` |  |
| global.cloudProvider | object | `{}` |  |
| global.environment | string | `""` |  |
| global.ingress.domain | string | `""` |  |
| global.metrics | object | `{}` |  |
| global.tracing | object | `{}` |  |
| image.repository | string | `"nginx"` |  |
| image.tag | string | `"latest"` |  |
| imagePullPolicy | string | `"Always"` |  |
| ingress.domain | string | `""` |  |
| ingress.enabled | bool | `false` |  |
| ingress.host | string | `""` |  |
| ingress.path | string | `"/"` |  |
| ingress.tls.enabled | bool | `true` |  |
| ingress.tls.secretName | string | `""` |  |
| initialDelaySeconds | int | `60` |  |
| internalServicePort | int | `80` |  |
| nameOverride | string | `""` |  |
| nodePort | int | `30001` |  |
| port | int | `8080` |  |
| prometheusExporter.enabled | bool | `false` |  |
| prometheusExporter.image.pullPolicy | string | `"IfNotPresent"` |  |
| prometheusExporter.image.repository | string | `"nginx/nginx-prometheus-exporter"` |  |
| prometheusExporter.image.tag | string | `"latest"` |  |
| prometheusExporter.resources.enabled | bool | `true` |  |
| prometheusExporter.resources.value.limits.cpu | string | `"100m"` |  |
| prometheusExporter.resources.value.limits.memory | string | `"128Mi"` |  |
| prometheusExporter.resources.value.requests.cpu | string | `"100m"` |  |
| prometheusExporter.resources.value.requests.memory | string | `"128Mi"` |  |
| replicaCount | int | `1` |  |
| resetOnConfigChange | bool | `true` |  |
| resources.enabled | bool | `true` |  |
| resources.value.limits.cpu | string | `"100m"` |  |
| resources.value.limits.memory | string | `"128Mi"` |  |
| resources.value.requests.cpu | string | `"100m"` |  |
| resources.value.requests.memory | string | `"128Mi"` |  |
| route.enabled | bool | `true` |  |
| route.rewriteTarget | string | `""` |  |
| route.routesMapping[0].host | string | `nil` |  |
| route.routesMapping[0].path | string | `"/"` |  |
| route.timeout.duration | string | `"60s"` |  |
| route.timeout.enabled | bool | `false` |  |
| route.tls.caCertificate | string | `""` |  |
| route.tls.certificate | string | `""` |  |
| route.tls.enabled | bool | `true` |  |
| route.tls.insecureEdgeTerminationPolicy | string | `"Redirect"` |  |
| route.tls.key | string | `""` |  |
| route.tls.termination | string | `"edge"` |  |
| route.tls.useCerts | bool | `false` |  |
| sidecars | string | `""` |  |
| siteStatusPort | int | `8081` |  |
| targetPort | int | `8080` |  |

