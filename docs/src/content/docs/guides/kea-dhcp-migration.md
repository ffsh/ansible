---
title: Gateway DHCP migration
description: Roll out Kea DHCPv4 safely and retain the ISC rollback path.
---

Gateway deployments configure Kea DHCPv4. The Kea role expects the
`ffsh/dhcp-static` repository to publish `/reservations.json` as a JSON array
of Kea reservation objects, for example:

```json
[
  {
    "hw-address": "18:b1:69:cd:34:ff",
    "ip-address": "10.144.1.4"
  }
]
```

Keep the existing ISC `static.conf` in that repository during the migration
window so rollback remains available. Do not run ISC and Kea simultaneously on
the same gateway.

Validate a single gateway after cutover, then roll out host by host:

```sh
ansible-playbook --vault-id=fastd_key@prompt setup.yml \
  --limit <gateway> --tags kea-dhcp4-server
```

The previous `isc-dhcp4-server` tag remains an alias during the transition.
To restore ISC DHCP on one gateway:

```sh
ansible-playbook --vault-id=fastd_key@prompt dhcp-rollback.yml \
  --limit <gateway>
```
