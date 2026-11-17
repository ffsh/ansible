---
title: WireGuard exit configuration
description: Configure the optional Mullvad WireGuard exit using encrypted host variables.
---

When `enable_wireguard_exit` is enabled, Ansible deploys WireGuard and attempts
to generate a Mullvad configuration with
[wg-conf-gen](https://github.com/ffsh/wg-conf-gen). The generator calls the
Mullvad API and selects a gateway based on the configured country and city.

Keep credentials in encrypted `host_vars/<gateway>.yml` files. Create or edit
one with:

```sh
ansible-vault create --vault-id fastd_key@prompt "host_vars/$gatewayname.yml"
ansible-vault edit --vault-id fastd_key@prompt "host_vars/$gatewayname.yml"
```

| Variable | Purpose |
| --- | --- |
| `fastd_secret` | Fastd secret key. Obtain its password through the NOC team. |
| `wg_device` | Optional name for the generated WireGuard device. |
| `wg_pk` | Mullvad-provided WireGuard private key. |
| `wg_address` | Mullvad-provided IPv4 and IPv6 addresses. |
| `wg_country` | Country used to select a Mullvad gateway. |
| `wg_city` | City used to select a Mullvad gateway. |
| `ffshmon_mail` | Mail username exported as `FFSHMON_MAIL_USER`. |
| `ffshmon_pw` | Mail password exported as `FFSHMON_MAIL_PASSWORD`. |

Email alerts are enabled for ffshmon by passing `--email-alerts`. Never place
plaintext keys, passwords, or real host values in documentation or examples.
