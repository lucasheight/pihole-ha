#!/bin/sh
set -eu

: "${VIP:?VIP required, e.g. 192.168.1.53/24}"
: "${INTERFACE:?INTERFACE required, e.g. eth0}"
: "${SRC_IP:?SRC_IP required (this node)}"
: "${PEER_IPS:?PEER_IPS required, comma-separated}"
: "${AUTH_PASS:?AUTH_PASS required}"
STATE="${STATE:-BACKUP}"
PRIORITY="${PRIORITY:-100}"
ROUTER_ID="${ROUTER_ID:-53}"
CHECK_NAME="${CHECK_NAME:-pi.hole}"

if [ "${#AUTH_PASS}" -gt 8 ]; then
  echo "AUTH_PASS must be <= 8 chars (keepalived silently truncates)" >&2
  exit 1
fi

PEERS=$(echo "$PEER_IPS" | tr ',' '\n' | sed 's/^ *//;s/ *$//;/^$/d;s/^/        /')

umask 077
cat > /etc/keepalived/keepalived.conf <<CONF
global_defs {
    enable_script_security
    script_user root
}

vrrp_script chk_dns {
    script "/usr/local/bin/check_dns.sh ${CHECK_NAME}"
    interval 5
    timeout 3
    fall 2
    rise 2
}

vrrp_instance DNS {
    state ${STATE}
    interface ${INTERFACE}
    virtual_router_id ${ROUTER_ID}
    priority ${PRIORITY}
    advert_int 1
    unicast_src_ip ${SRC_IP}
    unicast_peer {
${PEERS}
    }
    authentication {
        auth_type PASS
        auth_pass ${AUTH_PASS}
    }
    virtual_ipaddress {
        ${VIP}
    }
    track_script {
        chk_dns
    }
}
CONF

keepalived --config-test -f /etc/keepalived/keepalived.conf || {
  echo "generated keepalived.conf failed validation" >&2
  exit 1
}

exec keepalived --dont-fork --log-console --log-detail -f /etc/keepalived/keepalived.conf
