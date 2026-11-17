---
title: Managing hosts and secrets
description: Add inventory hosts, connect over SSH, and manage encrypted variables.
---

## Inventory

Add gateways to `hosts.yml`, following an existing gateway entry such as
`brunsbach`. Place service hosts in their existing groups:

- `services_map` for the map stack (`batman`, `batctl`, `grafana_public`,
  `meshviewer`)
- `services_web` for the web stack (`batman`, `batctl`, `node_exporter`,
  `website`, `firmware_release`, `firmware_selector`, `fail2ban`,
  `unattended_upgrades`)
- `dns` for the standalone DNS host

Keep shared configuration in `group_vars/` and host-specific configuration in
`host_vars/`. Encrypt secrets with Ansible Vault; do not put plaintext
credentials in inventory or documentation.

## SSH access

Register the deployment key with the local SSH agent:

```sh
ssh-add "$keyfile"
```

If SSH reports a host-key issue, connect interactively and verify the host
fingerprint before accepting it:

```sh
ssh root@<gateway-host>
```

The SSH role adds the current maintainer keys and removes explicitly listed
revoked keys from root's `authorized_keys`. It leaves other keys, including
cloud-init keys, in place. The revoked public-key files are retained so those
exact keys can be removed; other keys belonging to a former maintainer must be
identified separately.

## Host variables

Create or edit an encrypted host-vars file with the `fastd_key` vault ID:

```sh
ansible-vault create --vault-id fastd_key@prompt "host_vars/$gatewayname.yml"
ansible-vault edit --vault-id fastd_key@prompt "host_vars/$gatewayname.yml"
```

Only add variables required by the host's roles. See
[WireGuard exit configuration](./wireguard-exit/) for the host variables used
by the optional Mullvad WireGuard setup.
