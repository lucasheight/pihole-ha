#!/bin/sh
# Healthy = local Pi-hole answers with an address. Deliberately local-only: an
# upstream/ISP outage must not fail every node and drop the VIP entirely.
# dig prints errors to stdout, so require exit 0 AND an address-shaped answer.
out=$(dig @127.0.0.1 "${1:-pi.hole}" +short +time=1 +tries=1) || exit 1
echo "$out" | grep -Eq '^[0-9a-fA-F:.]+$'
