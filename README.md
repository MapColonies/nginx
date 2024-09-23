# NGINX Docker Image & Helm Chart for Openshift

## Application Architecture Overview

![Application Architecture Overview](architecture.png)
  

This repository consists of two things:

1. NGINX `Dockerfile` and its necessary assets for building

2. NGINX `Helm Chart` including `NGINX Prometheus Exporter`.

  
  

## Docker Image

We are using `nginxinc/nginx-unprivileged` as a base image in order to run NGINX with non-root privileges so it's possible to run it in an Openshift cluster (as we know, Openshift does not allow running containers with root privileges).

Besides that the `Dockerfile` is pretty straight forward so you can check it out yourself.

  

### Main Config Files

1.  `/etc/nginx/conf.d/deafult.conf` - Main server configurations. This server runs on port `8080` and it should process all of incoming traffic.

2.  `/etc/nginx/conf.d/status_site.conf` - This server runs on port `8081` and provides access to basic status data. You should use this server in order to make `liveness` checks on your application. This server **should not** be accessible outside the cluster.

  

### OpenTelemetry Support

There's support for instrumenting NGINX with OpenTelemetry (currently only for tracing), simply provide these environment variables:

  

| Environment Variable | Description | Default Value |
| ---------------------------- | ---------------------------------------------- | ---- |
| `OTEL_SERVICE_NAME` | Name of service | `nginx-proxy` |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | Endpoint address of OpenTelemetry Collector | `localhost:4317` |
| `OTEL_TRACES_SAMPELR` | Sampling method | `AlwaysOff` |
| `OTEL_TRACES_SAMPLER_RATIO` | Sampling ratio | `0.1` |
| `OTEL_TRACES_SAMPLER_PARENT_BASED` | Use parent-based sampling | `false` |

  

### Authroization Mechanism

Since we are using [Open Policy Agent](https://www.openpolicyagent.org/) (aka `OPA`) as our gatekeeper, it's necessary to integrate NGINX with it.

* The docker image contains the `auth.js` file, which is responsible for handling requests that require authorization **but** the NGINX server does not actually handle the authorization process - we commented the code section responsible for this logic.

  

### Log Format

The docker image provides default log format (`/etc/nginx/log_format`). It's not possible to extend the log format, so if you'd want to add/remove certain fields you have to override it.

  
  

## Helm Chart

There is also an Helm Chart for deploying this NGINX in an Openshift environment (let alone any K8S environment). 
Besides NGINX, this Helm Chart also deploys (on deamend) a Prometheus exporter for NGINX using [nginx-prometheus-exporter](https://github.com/nginxinc/nginx-prometheus-exporter/). Follow the parameters below in order to configure NGINX and its Prometheus exporter as you wish.

### Parameters

These are the main parameters you should adjust when you deploy this Helm Chart. You can find all parameters in the `values.yaml` file.

  #### NGINX Parameters
<!-- HELM_DOCS_START -->
# nginx

![Version: 1.3.0](https://img.shields.io/badge/Version-1.3.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 1.0.0](https://img.shields.io/badge/AppVersion-1.0.0-informational?style=flat-square)

A Helm chart for nginx

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| additionalPodAnnotations | object | `{}` | Use this property in order to add custom annotations to the Pod |
| authorization.domain | string | `"example"` | Your authorization domain |
| authorization.enabled | bool | `true` | Use authroization mechanism |
| authorization.url | string | `"http://localhost:8181/v1/data/http/authz/decision"` | Authorization endpoint |
| caKey | string | `"ca.crt"` | Key in the CA secret that contains the certificate data |
| caPath | string | `"/usr/local/share/ca-certificates"` | Path where the CA certificate will be mounted in the container |
| caSecretName | string | `""` | Name of the Kubernetes secret containing the CA certificate |
| cloudProvider | object | `{"dockerRegistryUrl":"my-registry-url","flavor":"openshift","imagePullSecretName":"imagepullsecret"}` | Specify the cloud provider where the chart is being deployed |
| cloudProvider.dockerRegistryUrl | string | `"my-registry-url"` | URL of the Docker registry to pull images from |
| cloudProvider.flavor | string | `"openshift"` | Specify the flavor of the deployment  |
| cloudProvider.imagePullSecretName | string | `"imagepullsecret"` | Name of the Kubernetes secret containing the image pull credentials |
| enabled | bool | `true` | Enable or disable the deployment of this chart |
| env.opentelemetry.exporterEndpoint | string | `"localhost:4317"` | OpenTelemetry Collector endpoint address |
| env.opentelemetry.parentBased | string | `"false"` | Use OpenTelemetry parnet-based sampling |
| env.opentelemetry.ratio | float | `0.1` | OpenTelemetry sampling ratio |
| env.opentelemetry.samplerMethod | string | `"AlwaysOff"` | OpenTelemetry sampling method |
| env.opentelemetry.serviceName | string | `"nginx"` | OpenTelemetry service name to be associated your NGINX application |
| environment | string | `"development"` | Specify the environment for this deployment  |
| extraVolumeMounts | list | `[]` | List of extra volumeMounts that are added to the NGINX container |
| extraVolumes | list | `[]` | List of extra volumes that are added to the Deployment |
| fullnameOverride | string | `""` | String to fully override fullname template |
| global.cloudProvider | object | `{}` | Global cloud provider configuration.  |
| global.environment | string | `""` | Global environment setting. |
| global.ingress.domain | string | `""` | Domain name for the ingress. |
| global.metrics | object | `{}` | Configuration for metrics collection. |
| global.tracing | object | `{}` | Configuration for distributed tracing.  |
| image.repository | string | `"nginx"` | Docker image name |
| image.tag | string | `"latest"` | Docker image tag |
| imagePullPolicy | string | `"Always"` | Image pull policy for all containers in the deployment |
| ingress.domain | string | `""` | Domain of ingress |
| ingress.enabled | bool | `false` | Expose NGINX as an Ingress |
| ingress.host | string | `""` | Host of ingress |
| ingress.path | string | `"/"` | Path of ingress |
| ingress.tls.enabled | bool | `true` | Use ingress over HTTPS |
| ingress.tls.secretName | string | `""` | Secret name of ingress that points to the relevant custom certificates |
| initialDelaySeconds | int | `60` | Initial delay in seconds before the readiness probe starts |
| internalServicePort | int | `80` | Internal ClusterIP service port |
| nameOverride | string | `""` | String to partially override fullname template (will maintain the release name) |
| nodePort | int | `30001` | Port to expose on each node for NodePort service type |
| port | int | `8080` | Port on which the application will listen |
| prometheusExporter.enabled | bool | `false` | Enable or disable the Prometheus exporter sidecar |
| prometheusExporter.image.pullPolicy | string | `"IfNotPresent"` | Image pull policy for the Prometheus exporter |
| prometheusExporter.image.repository | string | `"nginx/nginx-prometheus-exporter"` | Docker image name for the Prometheus exporter |
| prometheusExporter.image.tag | string | `"latest"` | Docker image tag for the Prometheus exporter |
| prometheusExporter.resources.enabled | bool | `true` | Enable or disable resource limits and requests |
| prometheusExporter.resources.value.limits.cpu | string | `"100m"` | CPU limit for the main container |
| prometheusExporter.resources.value.limits.memory | string | `"128Mi"` | Memory limit for the main container |
| prometheusExporter.resources.value.requests.cpu | string | `"100m"` | CPU request for the main container |
| prometheusExporter.resources.value.requests.memory | string | `"128Mi"` | Memory request for the main container |
| replicaCount | int | `1` | Number of replicas to deploy |
| resetOnConfigChange | bool | `true` | If true, triggers a rolling update when the configuration changes |
| resources.enabled | bool | `true` | Use custom resources |
| resources.value.limits.cpu | string | `"100m"` | Pod CPU limit |
| resources.value.limits.memory | string | `"128Mi"` | Pod memory limit |
| resources.value.requests.cpu | string | `"100m"` | Pod CPU request |
| resources.value.requests.memory | string | `"128Mi"` | Pod memory request |
| route.enabled | bool | `true` | Expose NGINX as an Openshift route |
| route.rewriteTarget | string | `""` | Rewrite route target |
| route.routesMapping[0] | object | `{"host":null,"path":"/"}` | Path of route |
| route.routesMapping[0].host | string | `nil` | Host of route |
| route.timeout.duration | string | `"60s"` | Set the timeout duration of the route. Defaults to 30s by Openshift |
| route.timeout.enabled | bool | `false` | Use custom timeout duration of the route |
| route.tls.caCertificate | string | `""` | Set the CA certificate of the route |
| route.tls.certificate | string | `""` | Set the certificate of the route |
| route.tls.enabled | bool | `true` | Use route over HTTPS |
| route.tls.insecureEdgeTerminationPolicy | string | `"Redirect"` | Policy for traffic on insecure schemes like HTTP |
| route.tls.key | string | `""` | Set the key of the route |
| route.tls.termination | string | `"edge"` | Set the termination of the route |
| route.tls.useCerts | bool | `false` | Use custom certificates for the route |
| sidecars | string | `""` | String consists of a list of sidecars containers that are added to the Deployment |
| siteStatusPort | int | `8081` | Port on which the site status will be available |
| targetPort | int | `8080` | Port to which the service will forward traffic |

<!-- HELM_DOCS_END -->

#### Overriding NGINX configuration files
If you wish to override the default configuration files, you can do it by providing an external ConfigMap and supplying Volumes & VolumeMounts that'll be added to the Deployment.
In this example we override the `default.conf` file by creating a ConfigMap and overriding the `extraVolumes`, `extraVolumeMounts` and `sidecars` sections:
```
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-extra-configmap
data:
  default.conf: {{ tpl (.Files.Get "config/default.conf") . | quote }}
```

And then, in the `values.yaml` file:
```
...
extraVolumes:
  - name: nginx-extra-config
    configMap:
    name: 'nginx-extra-configmap'
extraVolumeMounts:
  - name: nginx-extra-config
    mountPath: "/etc/nginx/conf.d/default.conf"
    subPath: default.conf
sidecars:
 - name: envoy
   image: "envoyproxy/envoy:v1.20.7"
   volumeMounts: []
   args: []
   resources: {}
   ports: []
...
```

#### Adding Custom Annotations
There's an option to dynamically add annotations to the pod. You might find it useful if you operate on different environments and need to custom your annotations. It can be done by editing the `additionalPodAnnotations` parameter.

  #### NGINX-Prometheus-Exporter Parameters
  | Name | Description | Value |
| ------------------------------------ | ----------------------------------------------------------- | ------- |
`prometheusExporter.enabled` | Enable / Disable the Prometheus exporter | `false`
`prometheusExporter.image.repostiory` | Prometheus exporter Docker image name | `nginx/nginx-prometheus-exporter`
`prometheusExporter.image.tag` | Prometheus exporter Docker image tag | `true`
`prometheusExporter.image.pullPolicy` | Image pull policy | `100m`
`prometheusExporter.resources.enabled` | Use custom resources | `100m`
`prometheusExporter.resources.value.limits.cpu` | Pod CPU limit | `100m`
`prometheusExporter.resources.value.limits.memory` | Pod memory limit | `128Mi`
`prometheusExporter.resources.value.requests.cpu` | Pod CPU request | `100m`
`prometheusExporter.resources.value.requests.memory` | Pod memory request | `128Mi`



