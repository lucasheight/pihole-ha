FROM alpine:3.21
RUN apk add --no-cache keepalived bind-tools && mkdir -p /etc/keepalived
COPY --chmod=755 entrypoint.sh check_dns.sh /usr/local/bin/
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD pidof keepalived >/dev/null || exit 1
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
