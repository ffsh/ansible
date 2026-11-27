---
title: Web host restoration
description: Procedure for rebuilding and restoring web-ffsh.
---

## Scope

This procedure restores the web host from Ansible and the normal external
sources. It does not describe the Ubuntu-to-Debian migration itself.

The following data has normal recovery sources and does not require a separate
host backup:

- Production static site: deployed from CI into `/var/www/web-static`
- Beta static site: deployed from CI into `/var/www/web-beta`
- Firmware selector: cloned from Git and managed by the `firmware_selector` role
- Stable, testing and RC firmware: recreated from GitHub releases
- Maintainer SSH keys and website deployment keys: restored by Ansible variables
- Fastd secret and mesh configuration: preserved or recreated by
  `fastd_client`

## 1. Install and prepare the replacement host

1. Install the target operating system and configure the host for Ansible SSH
   access.
2. Configure the public IPv4 address and default route using the provider's
   normal instance setup.
3. Update DNS only after the replacement host is ready.
4. Obtain a final copy of the encrypted Ansible Vault secrets and verify that
   the local inventory still points to `web-ffsh`.

Do not copy host files manually unless a step below explicitly requires it.
Ansible is the source of truth for packages, users, keys, nginx, Fastd and
mesh configuration.

## 2. Run Ansible

Run the web play in check mode first:

```sh
ansible-playbook --vault-id=fastd_key@prompt setup.yml \
  --limit services_web --check
```

If the check is valid, apply the web host:

```sh
ansible-playbook --vault-id=fastd_key@prompt setup.yml \
  --limit services_web
```

Before continuing, verify:

- SSH root access and maintainer keys
- `beta-deploy` and `website-deploy` users
- Fastd listens on UDP port `10000`
- `bat0` and its configured addresses exist
- nginx passes `nginx -t`
- Certbot certificates and renewal timer exist

## 3. Restore website content

The static websites are restored through their existing CI deployments:

- Production: trigger the production deployment workflow for
  `/var/www/web-static`.
- Beta: trigger the beta deployment workflow for `/var/www/web-beta`.
- Firmware selector: apply the `firmware_selector` role and verify
  `/var/www/firmware-selector`.

The production and beta deployment users and authorized public keys are
created by the `website` role. The matching private keys remain CI secrets.

TODO: Add the exact repository names and workflow names once confirmed.

## 4. Restore firmware

The role installs `/root/firmware-release.sh`. It downloads releases from
`ffsh/site` and maintains the following layout:

- `stable`: promoted firmware
- `testing`: the published release selected for testing
- `rc`: symlink to `testing` or `stable`

Restore stable firmware in one of these ways:

```sh
# Restore the latest stable release from GitHub
/root/firmware-release.sh publish latest

# Restore a specific release
/root/firmware-release.sh publish <release-tag>
```

The firmware release helper downloads and verifies the configured release
assets and updates `testing` and `rc`. The exact stable promotion step is:

```sh
/root/firmware-release.sh promote
```

Before promotion:

1. Verify that `testing/.release-version` contains the intended release.
2. Verify firmware listings and downloads for the target release.
3. Perform the manual firmware-signature check required for stable promotion.
4. Preserve the intended `testing` and `rc` symlinks after promotion.

TODO: Add the manual signature command or checklist used for stable firmware.

## 5. Restore TLS

The normal recovery is certificate renewal or reissuance. Before changing
certificate names or domains, record the certificate inventory:

```sh
certbot certificates
```

For a new host with no existing certificates:

1. Deploy nginx configuration through Ansible.
2. Set `website_auto_issue_tls=true` for initial certificate issuance.
3. Run the web role.
4. Verify nginx and the renewal timer.

Before removing this option, run a dry-run:

```sh
certbot renew --dry-run --nginx --no-random-sleep-on-renew
nginx -t
systemctl status certbot.timer
```

TODO: Document the saved renewal authenticator and installer behavior for each
certificate after renewal is tested end to end.

## 6. Restore Fastd and the mesh

Apply the shared client role:

```sh
ansible-playbook --vault-id=fastd_key@prompt setup.yml \
  --limit services_web --tags fastd-client
```

The role preserves an existing secret or generates one only for a new host.
The generated identity is acceptable while the gateways accept any Fastd key.

Verify:

```sh
systemctl status fastd@ffsh
ss -lunp 'sport = :10000'
ip -brief address
batctl meshif bat0 if
batctl meshif bat0 gw_mode
```

## 7. Final verification

- `nginx -t`
- Main and beta sites load
- Firmware selector loads
- Firmware files and the `stable`, `testing`, and `rc` layout are usable
- Certbot renewal dry-run succeeds
- Fastd is active and UDP port `10000` is bound
- node_exporter is reachable only on localhost and remains proxied at `/stats/`
- Fail2ban has the default `sshd` jail
- unattended-upgrades timers are active
- Certificate expiry and renewal metrics appear in Prometheus and Grafana
