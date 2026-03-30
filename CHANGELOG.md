# Changelog

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
