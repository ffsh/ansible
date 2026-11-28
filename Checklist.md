# web-ffsh automation checklist

## Host basics

- [ ] Debian migration blockers for `web-ffsh`:
  - Migration is planned to use a Debian snapshot rollback: preserve the current
    Ubuntu snapshot until web, Fastd, bat0, nginx, TLS and recovery commands are
    verified on Debian.
  - The web play currently accepts Ubuntu 24.04 or Debian 13.
  - The gateways already run Debian 13 and demonstrate that batman-adv,
    batctl, Fastd, DKMS, fail2ban, nftables, Certbot, nginx and systemd
    role patterns work on Debian. They reduce, but do not eliminate, the web
    migration risk.
  - `fastd_client` relies on `ifupdown` and `/etc/network/interfaces.d`; Debian
    network behavior must be validated with the target's interface manager and
    bat0 startup.
  - `batman` and `batctl` build from source and use Ubuntu-oriented
    `linux-headers-generic` dependencies. Replace or condition this dependency
    for Debian while retaining the source/DKMS build already used by gateways.
  - `batman`'s current 2026.x source build and netns hotfix need Debian kernel
    validation.
  - The unattended-upgrades role now selects Debian `trixie-security` origins
    or Ubuntu security plus ESM origins based on the operating system.
  - The service OS version may differ in fail2ban defaults, nftables integration,
    Fastd package support, Certbot package/plugin names, and systemd unit naming.
  - The migration must preserve the public address, route/DNS configuration,
    external interface name, Fastd UDP port 10000, bat0 MAC/address, SSH access,
    and nftables/fail2ban rules.

- [x] Manage maintainer SSH keys for root.
- [x] Deploy and verify the node_exporter role added to the web play. The
  existing service listens on `127.0.0.1:9100`; nginx proxies `/stats/` to it.
  The role installs the shared pinned version, enables the systemd and process
  collectors, and restarts the exporter.
- [x] Capture the web host and map host fastd/batman-adv client configuration.
  Both are mesh clients rather than gateways. They use UDP port 10000, accept
  peers through the shared `gateways` repository, have gateway mode off, and
  do not currently need gateway NAT or policy-routing rules. Web uses
  `ffsh-mesh`, bat0 MAC `00:5b:27:81:00:22`, and IPv6
  `fddf:bf7:80::222:1`. Map uses `mesh-vpn`, bat0 IPv4 `10.144.3.3/16`,
  IPv6 `fddf:bf7:80::333:3/48`, and bat0 MAC `00:5b:27:80:03:33`. The dedicated
  `fastd_client` role now manages the shared client setup and preserves an
  existing Fastd secret or generates one only for a new host.
- [x] Add the fail2ban role to the web host play and preserve Debian's default
  `sshd` jail. UFW is inactive, but nftables contains fail2ban rules; check for
  any additional external firewall rules.
- [x] Capture unattended-upgrades configuration and update policy: security and
  ESM security origins only, daily, no automatic reboot (the play reboots when
  required). Previously the host used Ubuntu's defaults, which also included
  `noble` (non-security) updates. Verify with `apt-config dump | grep
  Unattended-Upgrade` after the first deployment.
- [ ] Document backup and restore procedures for website and firmware data.
  A draft restoration procedure is in
  `docs/src/content/docs/guides/web-host-restoration.md`; fill in exact CI
  repositories, private deployment-key handling, firmware signature and release
  commands, and certificate recovery details.

## Websites and nginx

- [ ] Preserve the main static site at `/var/www/web-static` and beta at
  `/var/www/web-beta`, including their separate deployment users and CI keys.
- [x] Correct the README: the old WordPress files were intentionally removed
  after the static site proved stable; they are not a rollback option.
- [x] Remove PHP installation and the obsolete WordPress nginx templates.
- [x] Deploy the managed `install.freifunk-suedholstein.de` vhost using the
  existing nginx site filename, HTTP redirect and TLS certificate.
- [x] Verify the selector page, firmware listings and downloads after deployment.
- [x] Remove `ffshev.de` and its aliases from the intended configuration; the
  group no longer owns the domain. The firmware vhost has no ffshev aliases, the
  `ffshev` site is disabled by the website role, and the unused
  `firmware.conf.j2` template was removed. The `ffshev.de` zone was also dropped
  from the gateway BIND config; the firmware repository no longer references
  the domain.
- [x] Resolve the duplicate firmware vhosts. The managed firmware vhost now
  retains HTTP downloads (`serve_http`), the firmware access log, CORS with
  exposed headers and autoindex, and the website role disables the old
  `ffsh-firmware.conf`. Verified on the host: `nginx -t` no longer reports
  conflicting firmware server names.
- [x] Decide which remaining legacy redirects to retain and who manages their
  DNS. `freifunk-stormarn.de`, `lauenburg.freifunk.net`, and
  `stormarn.freifunk.net` currently point to this host and redirect over HTTP;
  these are now managed HTTP-only redirects in the website role.
  `reinbek.freifunk.net` points elsewhere and returned HTTP 410; its HTTPS
  certificate validation also failed. The reinbek enabled-site symlink is now
  retired by the website role; the sites-available file is preserved.
- [x] Review nginx's remaining warnings and verify active vhosts after
  changes. The conflicting-name and `ffshev` warnings are resolved. Diagnosis:
  `freifunk-stormarn` and `lauenburg` formerly contained plain `listen 443` and
  `[::]:443` directives despite only defining HTTP-to-HTTPS redirects. They are
  now managed HTTP-only redirect vhosts, so re-run `nginx -t` and verify that
  the protocol-options warnings are gone. The `ssl_stapling` warnings were
  resolved by removing stapling from the vhost template. Do not remove configs
  solely because they look old.

## TLS and renewal

- [ ] Make certificate issuance, renewal, nginx reload, and the required
  `/etc/nginx/dhparam.pem` reproducible on a fresh host. The website role now
  generates 2048-bit DH parameters once and configures Certbot renewal through
  the nginx plugin. Certificate issuance remains opt-in, and renewal dry-runs
  are enabled with `website_verify_certbot_renewal=true`.
- [x] Capture beta certificate renewal in Ansible. Its saved authenticator is
  standalone, but the systemd override runs Certbot with `--nginx`; a beta
  renewal dry run with the nginx plugin succeeded.
- [ ] Capture the other certificates' nginx authenticator and installer
  behavior; verify renewal without allowing Certbot to make unintended changes
  to managed nginx configuration.
- [x] Review certificate names and domains before changes. The main certificate
  includes `lauenburg.freifunk.net`; the firmware certificate covers only
  `firmware.freifunk-suedholstein.de`, not the obsolete ffshev aliases.
- [x] Add certificate expiry and renewal monitoring. Blackbox TLS probes cover
  the main, beta, firmware and install hostnames. Prometheus warns at 30 days
  and alerts critically at 14 days. A daily Certbot renewal dry-run writes a
  node_exporter textfile metric that alerts when renewal fails.

## Firmware and verification

- [ ] Document firmware release publishing, promotion and recovery. The current
  `testing` and `rc` links point to `stable`; preserve the intended layout.
- [REJCECTED]Back up firmware releases and verify recovery before changing the layout.
- [REJECTED] Add checks for beta, selector, firmware downloads and retained redirects,
  in addition to the existing main-site probe.
- [ ] Verify a fresh deployment and a repeat deployment, including TLS,
  deployment keys, nginx validation and service availability.

## improvements
- [ ] node_exporter use password protection

