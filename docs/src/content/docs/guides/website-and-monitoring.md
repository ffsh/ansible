---
title: Website and monitoring services
description: Operational details for the web, DNS, and monitoring hosts.
---

## Website host

The website role runs on `web-ffsh`. It serves the main static site from
`/var/www/web-static` and the beta site from `/var/www/web-beta`; the role no
longer installs PHP. It also serves the firmware selector at
`install.freifunk-suedholstein.de` from `/var/www/firmware-selector`, using the
existing nginx site name `install` and the certificate at
`/etc/letsencrypt/live/install.freifunk-suedholstein.de/`.

The firmware site serves HTTP and HTTPS and allows cross-origin requests for
the selector. The role disables the old `ffsh-firmware.conf` and `ffshev`
enabled sites but does not remove their files from `sites-available`.

The role also manages the HTTP-only redirects for
`freifunk-stormarn.de`, `lauenburg.freifunk.net`, and
`stormarn.freifunk.net`. Each redirect returns HTTP 301 responses to
`https://freifunk-suedholstein.de` and does not listen on port 443 or request
a TLS certificate.

The role disables the retired `reinbek` nginx site because
`reinbek.freifunk.net` is managed elsewhere. It leaves the legacy file in
`sites-available` untouched so it can be inspected or restored manually.

The role generates `/etc/nginx/dhparam.pem` once with 2048-bit parameters and
configures the packaged Certbot renewal timer to use the nginx plugin. Set
`website_verify_certbot_renewal: true` for a deployment to run
`certbot renew --dry-run --nginx --no-random-sleep-on-renew` after nginx
passes validation. Certificate issuance remains opt-in:
`website_auto_issue_tls: true`.

The Hugo repository's separate CI should deploy pushes to `main` to beta and
restrict production deployments to version tags. Use separate SSH keys for
each destination. Store only their public keys in the Ansible Vault variables
`vault_website_beta_deploy_public_key` and
`vault_website_prod_deploy_public_key`; keep the matching private keys in the
Hugo repository's CI secrets.

The web host's node_exporter listens on localhost and is exposed through the
website's `/stats/` proxy. Deploy it with:

```sh
ansible-playbook --vault-id=fastd_key@prompt setup.yml \
  --limit services_web --tags node_exporter
```

The role enables the systemd and process collectors and restarts the exporter.
As with other tagged deployments, `always` tasks can reboot the host if a
reboot is required.

The monitoring stack probes the main, beta, firmware, and install TLS
certificates through Blackbox. Prometheus warns when a certificate expires
within 30 days and alerts critically within 14 days. The web role also runs a
daily Certbot renewal dry-run and exports `ffsh_certbot_renewal_success` through
node_exporter; Prometheus alerts if the latest dry-run fails.

## fail2ban and unattended upgrades

The fail2ban role installs fail2ban and rsyslog and enables the `sshd` jail. It
bans an address after five failed attempts within one day for two hours;
loopback traffic is ignored:

```sh
ansible-playbook --vault-id=fastd_key@prompt setup.yml \
  --limit services_web --tags fail2ban
```

The unattended-upgrades role applies to web hosts and gateways. It enables
daily upgrades limited to security origins (including Ubuntu ESM security on
Ubuntu) through drop-ins, leaving the packaged
`50unattended-upgrades` file untouched. It does not reboot on its own; the play
reboots after a run when `/var/run/reboot-required` exists:

```sh
ansible-playbook --vault-id=fastd_key@prompt setup.yml \
  --limit services_web --tags unattended-upgrades
```

## DNS exporters

The standalone DNS host is in the `dns` group. Its play installs
node_exporter and bind_exporter; it does not manage the existing BIND service,
zones, or listening addresses.

Before deploying, configure the manually managed BIND instance to expose its
statistics channel on localhost at `http://127.0.0.1:8053/`, then reload BIND
and verify the endpoint. The bind_exporter service reads `/run/named/named.pid`.
Allow the monitoring host to reach TCP/UDP port 53 and TCP ports 9100 and 9119
as needed for DNS probes and exporter scrapes; restrict exporter access to
that monitoring host.

Deploy the exporters to the `bind` host with:

```sh
ansible-playbook --vault-id=fastd_key@prompt setup.yml \
  --limit bind --tags node_exporter,bind_exporter
```

The monitoring host probes `freifunk-suedholstein.de` as an `A` record against
the DNS host and exposes the result as the `blackbox-dns` Prometheus job.
