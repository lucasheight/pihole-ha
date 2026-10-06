# pihole-ha

Automatic DNS failover for Pi-hole across two (or more) Docker hosts using
keepalived/VRRP. One floating VIP; point your DHCP server (or clients) at the
VIP as the DNS server.

## Layout
- `keepalived/` image: config is generated from env vars at startup, so every
  node runs the same image and differs only by its `.env`.
- `compose.yaml` the keepalived service (host network, NET_ADMIN).
- `nodes/*.env.example` per-node values. Copy to `nodes/<node>.env` (gitignored).

## Deploy
    docker compose --env-file nodes/node1.env up -d

Config sync (blocklists, local DNS, groups) uses nebula-sync, enabled on one
node only, normally the one that is Pi-hole's primary:

    docker compose --env-file nodes/node1.env --profile sync up -d

Sync is one-way primary -> replicas. Make edits on the primary only. It targets
the nodes' own IPs, not the VIP, so it works whichever node holds the VIP.
Keep `SYNC_*` out of the other node's env file.

### Sync credentials
Nebula-sync logs in to each Pi-hole's API on every run, using the
`url|password` pairs in `SYNC_PRIMARY` / `SYNC_REPLICAS`.
- Pi-hole v6 only. Use an **app password** (Settings > Web interface / API >
  Configure app password) rather than your admin password. It works with 2FA
  enabled and can be revoked without changing the admin login.
- Each node needs its own entry; passwords can differ between nodes.
- The password is stored in plaintext in `nodes/<node>.env` (gitignored), so
  `chmod 600` it and never commit it.
- Avoid `|` in the password (it's the separator). Wrap values containing `$`
  in single quotes, or compose will try to interpolate them.
- Nebula-sync needs the Pi-hole web port reachable from the sync node. Use the
  nodes' own IPs, not the VIP.

For UI-based Docker managers (TrueNAS, Portainer, Unraid, etc.), paste
`compose.yaml` with the values inlined.

## Notes
- VIP must be outside your DHCP pool and unassigned.
- Pi-hole must publish 53 on 0.0.0.0 (or host network + listen on all interfaces).
- Don't point the Docker hosts' own nameservers at the VIP.
- Adding a third node (e.g. a Pi): add it to every node's PEER_IPS, PRIORITY=50.
- Test: `dig @<vip> example.com`, stop Pi-hole on the master, confirm the VIP
  moves (`ip -br a`) and queries keep resolving.
- `AUTH_PASS` is VRRP plaintext auth (max 8 chars): it stops accidental
  interference, not an attacker on the LAN.
- `ROUTER_ID` (VRRP virtual_router_id) must be unique on the L2 segment.
- `VIP` prefix length must match the LAN (e.g. /24).
- Both nodes start `BACKUP`; priority picks the master. node1 reclaims the VIP
  when it recovers (brief blip); add `nopreempt` in the entrypoint to disable.
- If your router advertises IPv6 DNS (RDNSS), clients may bypass the VIP.
- Deploy a pinned tag (`KEEPALIVED_TAG=v1.0.0` or `sha-...`), not `latest`.
  Forks: set `KEEPALIVED_IMAGE` to your own ghcr path.
- The entrypoint validates the generated config (`keepalived --config-test`)
  and the container has a `HEALTHCHECK`; CI smoke-tests both before pushing.
