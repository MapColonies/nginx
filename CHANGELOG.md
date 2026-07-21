# Changelog

## [2.3.0](https://github.com/MapColonies/nginx/compare/v2.2.2...v2.3.0) (2026-07-21)


### Features

* **auth:** export buildOpaBody for reuse by dependent gateways ([#55](https://github.com/MapColonies/nginx/issues/55)) ([2c63219](https://github.com/MapColonies/nginx/commit/2c6321969ac0d13a3c6ef99cd2f31c1ab9517068))

## [2.2.2](https://github.com/MapColonies/nginx/compare/v2.2.1...v2.2.2) (2026-07-20)


### Build System

* upgrade nginx base image to 1.29.8-alpine3.23-otel ([#53](https://github.com/MapColonies/nginx/issues/53)) ([12725ef](https://github.com/MapColonies/nginx/commit/12725ef9b1e9ef132328042dbcd156bcc2296ec4))

## [2.2.1](https://github.com/MapColonies/nginx/compare/v2.2.0...v2.2.1) (2026-06-23)


### Bug Fixes

* **log format:** service name should be taken from name override and default to nginx ([#51](https://github.com/MapColonies/nginx/issues/51)) ([19a5eca](https://github.com/MapColonies/nginx/commit/19a5eca60dbc67fd7e095474c753a060a745328a))

## [2.2.0](https://github.com/MapColonies/nginx/compare/v2.1.6...v2.2.0) (2026-06-23)


### Features

* changed opa headers mechanism from whitelist to blacklist ([#47](https://github.com/MapColonies/nginx/issues/47)) ([69de12f](https://github.com/MapColonies/nginx/commit/69de12f6f521925b4081257d62965f9a831fb507))


### Helm Changes

* move prometheus exporter image ([#49](https://github.com/MapColonies/nginx/issues/49)) ([f5cacc1](https://github.com/MapColonies/nginx/commit/f5cacc1126fb3ee30d2efc7c329bd609db912573))
* set nginx app name ([#50](https://github.com/MapColonies/nginx/issues/50)) ([e46fed7](https://github.com/MapColonies/nginx/commit/e46fed7c5d67d03ef44c4ee95a72361c44bab4e5))

## [2.1.6](https://github.com/MapColonies/nginx/compare/v2.1.5...v2.1.6) (2026-04-26)


### Helm Changes

* pass trace context to backend ([#45](https://github.com/MapColonies/nginx/issues/45)) ([79cda9e](https://github.com/MapColonies/nginx/commit/79cda9e9bca0bf5b122719f1883de2ea6dc66beb))

## [2.1.5](https://github.com/MapColonies/nginx/compare/v2.1.4...v2.1.5) (2026-04-16)


### Helm Changes

* allow disabling backend service ([#42](https://github.com/MapColonies/nginx/issues/42)) ([74f7089](https://github.com/MapColonies/nginx/commit/74f708975bcd9ccaf9526cac61102cffbaed27d6))

## [2.1.4](https://github.com/MapColonies/nginx/compare/v2.1.3...v2.1.4) (2026-04-15)


### Helm Changes

* add labels and selector labels ([#38](https://github.com/MapColonies/nginx/issues/38)) ([b12d0bf](https://github.com/MapColonies/nginx/commit/b12d0bf8d779bcc8bda7fb078a854806d88f700b))
* add mc labels and annotations ([#39](https://github.com/MapColonies/nginx/issues/39)) ([13b31cc](https://github.com/MapColonies/nginx/commit/13b31ccbc525fd78f2d40a889c0db6c59d9f00c9))
* allow adding additional nginx conf ([#32](https://github.com/MapColonies/nginx/issues/32)) ([3522a30](https://github.com/MapColonies/nginx/commit/3522a3093defd1192569c9fb9f2fe7b9f397a016))
* allow expanding NGINX configuration ([#35](https://github.com/MapColonies/nginx/issues/35)) ([f54e987](https://github.com/MapColonies/nginx/commit/f54e9878ed66e513538f043f811db81755a5c83b))


### Code Refactoring

* **helm:** move OpenTelemetry  otelRatioSampler to helpers and update nginx.conf ([#37](https://github.com/MapColonies/nginx/issues/37)) ([0a8f7fa](https://github.com/MapColonies/nginx/commit/0a8f7fa8e766164630cee51352ed02eb52f3350b))
* **helm:** move otel_trace directive to server scope ([#34](https://github.com/MapColonies/nginx/issues/34)) ([563e08c](https://github.com/MapColonies/nginx/commit/563e08ca7b57b539e1253dc3d2620c45763a268c))

## [2.1.3](https://github.com/MapColonies/nginx/compare/v2.1.2...v2.1.3) (2026-04-05)


### Helm Changes

* fix image version resolution ([#28](https://github.com/MapColonies/nginx/issues/28)) ([4e66eeb](https://github.com/MapColonies/nginx/commit/4e66eeb3373413e66d62293b33cf0b431aef3bb4))
* handle OPTIONS requests and allow setting allow headers and origins headers ([#29](https://github.com/MapColonies/nginx/issues/29)) ([60c6434](https://github.com/MapColonies/nginx/commit/60c64342041f893a1acd5844911d2009a8b51514))

## [2.1.2](https://github.com/MapColonies/nginx/compare/v2.1.1...v2.1.2) (2026-03-30)


### Bug Fixes

* **auth:** pass specific headers to OPA subrequest ([#22](https://github.com/MapColonies/nginx/issues/22)) ([d32d99c](https://github.com/MapColonies/nginx/commit/d32d99c171571d0215064fbc2d109aef1a62f2c3))
* **log format:** log format doesn't uphold opentelemetry field naming (MAPCO-8460) ([#17](https://github.com/MapColonies/nginx/issues/17)) ([3a03e84](https://github.com/MapColonies/nginx/commit/3a03e849e64f62bcea5ecdaf09b7ad333d428f18))

## [2.1.1](https://github.com/MapColonies/nginx/compare/v2.1.0...v2.1.1) (2026-03-19)


### Bug Fixes

* update OpenTelemetry field names in log format configuration ([#25](https://github.com/MapColonies/nginx/issues/25)) ([882f11e](https://github.com/MapColonies/nginx/commit/882f11ea0520719171cbcad70b8e913f9a34e5c9))

## [2.1.0](https://github.com/MapColonies/nginx/compare/v2.0.0...v2.1.0) (2025-09-10)


### Features

* upgraded nginx to 1.28.0 with updated otel module ([#15](https://github.com/MapColonies/nginx/issues/15)) ([886ae23](https://github.com/MapColonies/nginx/commit/886ae23bce9b1ce54fba30e13defd33b730407ec))


### Bug Fixes

* nginx log format typos ([#16](https://github.com/MapColonies/nginx/issues/16)) ([670f404](https://github.com/MapColonies/nginx/commit/670f404d034b483a90e0370fec7d529fe751c4e9))


### Helm Changes

* add Access-Control-Max-Age header to Nginx configuration ([#14](https://github.com/MapColonies/nginx/issues/14)) ([0c1db27](https://github.com/MapColonies/nginx/commit/0c1db2726988b26dbd0a0f6a15f0b1e462d36337))
