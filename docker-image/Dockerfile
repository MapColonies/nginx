FROM nginxinc/nginx-unprivileged:1.28.0-alpine3.21-otel

USER root

ENV OTEL_HOST=localhost
ENV OTEL_PORT=4317

# RUN mkdir /otel
COPY nginx-config/auth.js /etc/nginx/
COPY nginx-config/status_site.conf /etc/nginx/conf.d/
# COPY otel-assets/* /otel/
