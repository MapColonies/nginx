#!/bin/sh
cat /otel/otel-nginx-template.toml | envsubst > /otel/otel-nginx.toml
