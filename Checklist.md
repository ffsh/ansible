# web-ffsh automation checklist

## Host basics

- [x] Manage maintainer SSH keys for root.
- [x] Deploy and verify the node_exporter role added to the web play. The
  existing service listens on `127.0.0.1:9100`; nginx proxies `/stats/` to it.
  The role installs the shared pinned version, enables the systemd and process
  collectors, and restarts the exporter.
- [ ] Capture the web host's fastd and batman-adv configuration, including
  `ffsh-mesh`, `bat0`, its addresses, peers and secrets. Fastd currently listens
  on UDP port 10000. The gateway fastd role has gateway-specific settings and
  must not be applied unchanged.
- [x] Add the fail2ban role to the web host play and preserve Debian's default
  `sshd` jail. UFW is inactive, but nftables contains fail2ban rules; check for
  any additional external firewall rules.
- [x] Capture unattended-upgrades configuration and update policy: security and
  ESM security origins only, daily, no automatic reboot (the play reboots when
  required). Previously the host used Ubuntu's defaults, which also included
  `noble` (non-security) updates. Verify with `apt-config dump | grep
  Unattended-Upgrade` after the first deployment.
- [ ] Document backup and restore procedures for website and firmware data.

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
  `ffsh-firmware.conf`. Confirm on the host that `nginx -t` no longer reports
  conflicting firmware server names after deployment.
- [ ] Decide which remaining legacy redirects to retain and who manages their
  DNS. `freifunk-stormarn.de`, `lauenburg.freifunk.net`, and
  `stormarn.freifunk.net` currently point to this host and redirect over HTTP;
  HTTPS certificate validation failed for each. `reinbek.freifunk.net` points
  elsewhere and returned HTTP 410; its HTTPS certificate validation also failed.
- [ ] Review nginx's listener/protocol warnings and verify active vhosts after
  changes. Do not remove configs solely because they look old.

## TLS and renewal

- [ ] Make certificate issuance, renewal, nginx reload, and the required
  `/etc/nginx/dhparam.pem` reproducible on a fresh host.
- [ ] Capture beta certificate renewal in Ansible. Its saved authenticator is
  standalone, but the systemd override runs Certbot with `--nginx`; a beta
  renewal dry run with the nginx plugin succeeded.
- [ ] Capture the other certificates' nginx authenticator and installer
  behavior; verify renewal without allowing Certbot to make unintended changes
  to managed nginx configuration.
- [ ] Review certificate names and domains before changes. The main certificate
  includes `lauenburg.freifunk.net`; the firmware certificate covers only
  `firmware.freifunk-suedholstein.de`, not the obsolete ffshev aliases.
- [ ] Add certificate expiry and renewal monitoring.

## Firmware and verification

- [ ] Document firmware release publishing, promotion and recovery. The current
  `testing` and `rc` links point to `stable`; preserve the intended layout.
- [ ] Back up firmware releases and verify recovery before changing the layout.
- [ ] Add checks for beta, selector, firmware downloads and retained redirects,
  in addition to the existing main-site probe.
- [ ] Verify a fresh deployment and a repeat deployment, including TLS,
  deployment keys, nginx validation and service availability.

## improvements
- [ ] node_exporter use password protection

## Command output
root@web:~# ls /var/www/
firmware  firmware-selector  honeypot  html  web-beta  web-static


root@web:~# ls /etc/nginx/sites-available/
badoldesloe                         default  ffsh-firmware.conf  firmware-freifunk-suedholstein-de.conf  freifunk-suedholstein-de.conf  install    reinbek
beta-freifunk-suedholstein-de.conf  ffshev   ffsh-main.conf      freifunk-stormarn                       honeypot                       lauenburg  stormarn


root@web:~# ls /etc/nginx/sites-enabled/
beta-freifunk-suedholstein-de.conf  ffsh-firmware.conf                      freifunk-stormarn              install    reinbek
ffshev                              firmware-freifunk-suedholstein-de.conf  freifunk-suedholstein-de.conf  lauenburg  stormarn


root@web:~# nginx -t
ls -l /etc/nginx/sites-enabled/
nginx -T 2>&1 | grep -E '(^# configuration file|server_name|listen |root |alias |proxy_pass|ssl_certificate |access_log|include )'
2026/11/16 18:54:32 [warn] 1575#1575: protocol options redefined for 0.0.0.0:443 in /etc/nginx/sites-enabled/ffshev:4
2026/11/16 18:54:32 [warn] 1575#1575: protocol options redefined for [::]:443 in /etc/nginx/sites-enabled/ffshev:5
2026/11/16 18:54:32 [warn] 1575#1575: protocol options redefined for 0.0.0.0:443 in /etc/nginx/sites-enabled/firmware-freifunk-suedholstein-de.conf:4
2026/11/16 18:54:32 [warn] 1575#1575: protocol options redefined for [::]:443 in /etc/nginx/sites-enabled/firmware-freifunk-suedholstein-de.conf:5
2026/11/16 18:54:32 [warn] 1575#1575: protocol options redefined for 0.0.0.0:443 in /etc/nginx/sites-enabled/freifunk-stormarn:4
2026/11/16 18:54:32 [warn] 1575#1575: protocol options redefined for [::]:443 in /etc/nginx/sites-enabled/freifunk-stormarn:5
2026/11/16 18:54:32 [warn] 1575#1575: protocol options redefined for 0.0.0.0:443 in /etc/nginx/sites-enabled/freifunk-suedholstein-de.conf:13
2026/11/16 18:54:32 [warn] 1575#1575: protocol options redefined for [::]:443 in /etc/nginx/sites-enabled/freifunk-suedholstein-de.conf:14
2026/11/16 18:54:32 [warn] 1575#1575: protocol options redefined for 0.0.0.0:443 in /etc/nginx/sites-enabled/lauenburg:4
2026/11/16 18:54:32 [warn] 1575#1575: protocol options redefined for [::]:443 in /etc/nginx/sites-enabled/lauenburg:5
2026/11/16 18:54:32 [warn] 1575#1575: "ssl_stapling" ignored, no OCSP responder URL in the certificate "/etc/letsencrypt/live/beta.freifunk-suedholstein.de/fullchain.pem"
2026/11/16 18:54:32 [warn] 1575#1575: "ssl_stapling" ignored, no OCSP responder URL in the certificate "/etc/letsencrypt/live/firmware.freifunk-suedholstein.de/fullchain.pem"
2026/11/16 18:54:32 [warn] 1575#1575: "ssl_stapling" ignored, no OCSP responder URL in the certificate "/etc/letsencrypt/live/firmware.freifunk-suedholstein.de/fullchain.pem"
2026/11/16 18:54:32 [warn] 1575#1575: "ssl_stapling" ignored, no OCSP responder URL in the certificate "/etc/letsencrypt/live/freifunk-suedholstein.de/fullchain.pem"
2026/11/16 18:54:32 [warn] 1575#1575: "ssl_stapling" ignored, no OCSP responder URL in the certificate "/etc/letsencrypt/live/install.freifunk-suedholstein.de/fullchain.pem"
2026/11/16 18:54:32 [warn] 1575#1575: conflicting server name "firmware.freifunk-suedholstein.de" on 0.0.0.0:443, ignored
2026/11/16 18:54:32 [warn] 1575#1575: conflicting server name "firmware.ffshev.de" on 0.0.0.0:443, ignored
2026/11/16 18:54:32 [warn] 1575#1575: conflicting server name "fw.ffshev.de" on 0.0.0.0:443, ignored
2026/11/16 18:54:32 [warn] 1575#1575: conflicting server name "firmware.freifunk-suedholstein.de" on [::]:443, ignored
2026/11/16 18:54:32 [warn] 1575#1575: conflicting server name "firmware.ffshev.de" on [::]:443, ignored
2026/11/16 18:54:32 [warn] 1575#1575: conflicting server name "fw.ffshev.de" on [::]:443, ignored
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
total 8
lrwxrwxrwx 1 root root 61 Sep 29 11:44 beta-freifunk-suedholstein-de.conf -> /etc/nginx/sites-available/beta-freifunk-suedholstein-de.conf
lrwxrwxrwx 1 root root 33 Sep 26  2023 ffshev -> /etc/nginx/sites-available/ffshev
lrwxrwxrwx 1 root root 45 Sep 29 11:04 ffsh-firmware.conf -> /etc/nginx/sites-available/ffsh-firmware.conf
lrwxrwxrwx 1 root root 65 Sep 29 11:35 firmware-freifunk-suedholstein-de.conf -> /etc/nginx/sites-available/firmware-freifunk-suedholstein-de.conf
lrwxrwxrwx 1 root root 44 Sep 11  2020 freifunk-stormarn -> /etc/nginx/sites-available/freifunk-stormarn
lrwxrwxrwx 1 root root 56 Sep 29 11:35 freifunk-suedholstein-de.conf -> /etc/nginx/sites-available/freifunk-suedholstein-de.conf
lrwxrwxrwx 1 root root 34 Jun 10  2019 install -> /etc/nginx/sites-available/install
lrwxrwxrwx 1 root root 36 Jun 12  2020 lauenburg -> /etc/nginx/sites-available/lauenburg
lrwxrwxrwx 1 root root 34 Sep 11  2020 reinbek -> /etc/nginx/sites-available/reinbek
lrwxrwxrwx 1 root root 35 Sep 11  2020 stormarn -> /etc/nginx/sites-available/stormarn
# configuration file /etc/nginx/nginx.conf:
include /etc/nginx/modules-enabled/*.conf;
        # server_names_hash_bucket_size 64;
        # server_name_in_redirect off;
        include /etc/nginx/mime.types;
        access_log /var/log/nginx/access.log;
        include /etc/nginx/conf.d/*.conf;
        include /etc/nginx/sites-enabled/*;
#               listen     localhost:110;
#               listen     localhost:143;
# configuration file /etc/nginx/mime.types:
# configuration file /etc/nginx/sites-enabled/beta-freifunk-suedholstein-de.conf:
    listen 80;
    listen [::]:80;
    server_name beta.freifunk-suedholstein.de;
    access_log off;
        listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name beta.freifunk-suedholstein.de;
    root /var/www/web-beta;
    access_log off;
        ssl_certificate /etc/letsencrypt/live/beta.freifunk-suedholstein.de/fullchain.pem;
# configuration file /etc/nginx/sites-enabled/ffsh-firmware.conf:
    listen 80;
    listen [::]:80;
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    ssl_certificate /etc/letsencrypt/live/firmware.freifunk-suedholstein.de/fullchain.pem;
    root /var/www/firmware;
    server_name firmware.freifunk-suedholstein.de firmware.ffshev.de fw.ffshev.de;
        access_log /var/log/nginx/firmware.log;
# configuration file /etc/nginx/sites-enabled/ffshev:
    listen 80;
    listen [::]:80;
    listen 443;
    listen [::]:443;
    server_name www.ffshev.de ffshev.de;
# configuration file /etc/nginx/sites-enabled/firmware-freifunk-suedholstein-de.conf:
        listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name firmware.freifunk-suedholstein.de firmware.ffshev.de fw.ffshev.de;
    root /var/www/firmware;
    access_log off;
        ssl_certificate /etc/letsencrypt/live/firmware.freifunk-suedholstein.de/fullchain.pem;
# configuration file /etc/nginx/sites-enabled/freifunk-stormarn:
    listen 80;
    listen [::]:80;
    listen 443;
    listen [::]:443;
    server_name freifunk-stormarn.de;
# configuration file /etc/nginx/sites-enabled/freifunk-suedholstein-de.conf:
    listen 80;
    listen [::]:80;
    server_name freifunk-suedholstein.de www.freifunk-suedholstein.de;
    access_log off;
        listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name freifunk-suedholstein.de www.freifunk-suedholstein.de;
    root /var/www/web-static;
    access_log off;
        proxy_pass http://127.0.0.1:9100/;
        ssl_certificate /etc/letsencrypt/live/freifunk-suedholstein.de/fullchain.pem;
# configuration file /etc/nginx/sites-enabled/install:
    listen 80;
    listen [::]:80;
    server_name install.freifunk-suedholstein.de;
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name install.freifunk-suedholstein.de;
    root /var/www/firmware-selector;
    access_log off;
        access_log off;
        access_log off;
    ssl_certificate /etc/letsencrypt/live/install.freifunk-suedholstein.de/fullchain.pem;
# configuration file /etc/nginx/sites-enabled/lauenburg:
    listen 80;
    listen [::]:80;
    listen 443;
    listen [::]:443;
    server_name lauenburg.freifunk.net;
# configuration file /etc/nginx/sites-enabled/reinbek:
    listen 80;
    listen [::]:80;
    listen 443;
    listen [::]:443;
    server_name reinbek.freifunk.net;
# configuration file /etc/nginx/sites-enabled/stormarn:
    listen 80;
    listen [::]:80;
    listen 443;
    listen [::]:443;
    server_name stormarn.freifunk.net;


root@web:~# certbot certificates
systemctl list-timers --all | grep -i certbot
systemctl status certbot.timer --no-pager
ls -l /etc/letsencrypt/renewal/
ls -l /etc/nginx/dhparam.pem
Saving debug log to /var/log/letsencrypt/letsencrypt.log

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Found the following certs:
  Certificate Name: beta.freifunk-suedholstein.de
    Serial Number: 50895f14a24e1445207f97c7c817e95dda8
    Key Type: ECDSA
    Domains: beta.freifunk-suedholstein.de
    Expiry Date: 2026-12-28 08:51:50+00:00 (VALID: 41 days)
    Certificate Path: /etc/letsencrypt/live/beta.freifunk-suedholstein.de/fullchain.pem
    Private Key Path: /etc/letsencrypt/live/beta.freifunk-suedholstein.de/privkey.pem
  Certificate Name: firmware.freifunk-suedholstein.de
    Serial Number: 50148b883aff8eb177f24b901767ac14cfc
    Key Type: RSA
    Domains: firmware.freifunk-suedholstein.de
    Expiry Date: 2027-01-25 11:45:56+00:00 (VALID: 69 days)
    Certificate Path: /etc/letsencrypt/live/firmware.freifunk-suedholstein.de/fullchain.pem
    Private Key Path: /etc/letsencrypt/live/firmware.freifunk-suedholstein.de/privkey.pem
  Certificate Name: freifunk-suedholstein.de
    Serial Number: 6cf494892e0ac919a2a30e72dde695fd828
    Key Type: RSA
    Domains: freifunk-suedholstein.de lauenburg.freifunk.net www.freifunk-suedholstein.de
    Expiry Date: 2026-12-23 20:56:34+00:00 (VALID: 37 days)
    Certificate Path: /etc/letsencrypt/live/freifunk-suedholstein.de/fullchain.pem
    Private Key Path: /etc/letsencrypt/live/freifunk-suedholstein.de/privkey.pem
  Certificate Name: install.freifunk-suedholstein.de
    Serial Number: 561c1118960667a5af3b15085419a592307
    Key Type: RSA
    Domains: install.freifunk-suedholstein.de
    Expiry Date: 2027-01-25 11:46:08+00:00 (VALID: 69 days)
    Certificate Path: /etc/letsencrypt/live/install.freifunk-suedholstein.de/fullchain.pem
    Private Key Path: /etc/letsencrypt/live/install.freifunk-suedholstein.de/privkey.pem
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Tue 2026-11-17 00:22:01 CET 5h 26min Mon 2026-11-16 04:54:21 CET        - certbot.timer                  certbot.service
● certbot.timer - Run certbot twice daily
     Loaded: loaded (/usr/lib/systemd/system/certbot.timer; enabled; preset: enabled)
     Active: active (waiting) since Mon 2026-11-16 18:45:18 CET; 10min ago
    Trigger: Tue 2026-11-17 00:22:01 CET; 5h 26min left
   Triggers: ● certbot.service

Nov 16 18:45:18 web systemd[1]: Started certbot.timer - Run certbot twice daily.
total 16
-rw-r--r-- 1 root root 605 Sep 29 11:50 beta.freifunk-suedholstein.de.conf
-rw-r--r-- 1 root root 636 Oct 27 13:44 firmware.freifunk-suedholstein.de.conf
-rw-r--r-- 1 root root 620 Sep 24 23:55 freifunk-suedholstein.de.conf
-rw-r--r-- 1 root root 631 Oct 27 13:44 install.freifunk-suedholstein.de.conf
-rw-r--r-- 1 root root 425 Jun  9  2019 /etc/nginx/dhparam.pem
root@web:~# du -sh /var/www/* 2>/dev/null
find /var/www -maxdepth 2 -type l -ls
ss -lntup
systemctl list-units --type=service --state=running
3.8G    /var/www/firmware
16M     /var/www/firmware-selector
4.1M    /var/www/honeypot
8.0K    /var/www/html
13M     /var/www/web-beta
13M     /var/www/web-static
   256198      0 lrwxrwxrwx   1 root     root           24 Sep  5 11:54 /var/www/firmware/rc -> /var/www/firmware/stable
   256153      0 lrwxrwxrwx   1 root     root           24 Sep  5 11:54 /var/www/firmware/testing -> /var/www/firmware/stable
Netid     State      Recv-Q     Send-Q                Local Address:Port            Peer Address:Port     Process
udp       UNCONN     0          0                        127.0.0.54:53                   0.0.0.0:*         users:(("systemd-resolve",pid=824,fd=16))
udp       UNCONN     0          0                     127.0.0.53%lo:53                   0.0.0.0:*         users:(("systemd-resolve",pid=824,fd=14))
udp       UNCONN     0          0                116.203.27.68%eth0:68                   0.0.0.0:*         users:(("systemd-network",pid=676,fd=22))
udp       UNCONN     0          0                           0.0.0.0:68                   0.0.0.0:*         users:(("dhclient",pid=694,fd=7))
udp       UNCONN     0          0                            *%eth0:10000                      *:*         users:(("fastd",pid=954,fd=9))
tcp       LISTEN     0          4096                      127.0.0.1:9100                 0.0.0.0:*         users:(("node_exporter",pid=924,fd=3))
tcp       LISTEN     0          4096                  127.0.0.53%lo:53                   0.0.0.0:*         users:(("systemd-resolve",pid=824,fd=15))
tcp       LISTEN     0          511                         0.0.0.0:443                  0.0.0.0:*         users:(("nginx",pid=1041,fd=8),("nginx",pid=1039,fd=8))
tcp       LISTEN     0          4096                     127.0.0.54:53                   0.0.0.0:*         users:(("systemd-resolve",pid=824,fd=17))
tcp       LISTEN     0          4096                        0.0.0.0:22                   0.0.0.0:*         users:(("sshd",pid=1081,fd=3),("systemd",pid=1,fd=87))
tcp       LISTEN     0          511                         0.0.0.0:80                   0.0.0.0:*         users:(("nginx",pid=1041,fd=6),("nginx",pid=1039,fd=6))
tcp       LISTEN     0          511                            [::]:443                     [::]:*         users:(("nginx",pid=1041,fd=9),("nginx",pid=1039,fd=9))
tcp       LISTEN     0          4096                           [::]:22                      [::]:*         users:(("sshd",pid=1081,fd=4),("systemd",pid=1,fd=88))
tcp       LISTEN     0          511                            [::]:80                      [::]:*         users:(("nginx",pid=1041,fd=7),("nginx",pid=1039,fd=7))
  UNIT                        LOAD   ACTIVE SUB     DESCRIPTION
  accounts-daemon.service     loaded active running Accounts Service
  atd.service                 loaded active running Deferred execution scheduler
  cron.service                loaded active running Regular background program processing daemon
  dbus.service                loaded active running D-Bus System Message Bus
  fail2ban.service            loaded active running Fail2Ban Service
  fastd.service               loaded active running LSB: Fast and Secure Tunneling Daemon
  getty@tty1.service          loaded active running Getty on tty1
  lxcfs.service               loaded active running FUSE filesystem for LXC
  multipathd.service          loaded active running Device-Mapper Multipath Device Controller
  nginx.service               loaded active running A high performance web server and a reverse proxy server
  node_exporter.service       loaded active running Node Exporter
  polkit.service              loaded active running Authorization Manager
  qemu-guest-agent.service    loaded active running QEMU Guest Agent
  rsyslog.service             loaded active running System Logging Service
  serial-getty@ttyS0.service  loaded active running Serial Getty on ttyS0
  ssh.service                 loaded active running OpenBSD Secure Shell server
  systemd-journald.service    loaded active running Journal Service
  systemd-logind.service      loaded active running User Login Management
  systemd-networkd.service    loaded active running Network Configuration
  systemd-resolved.service    loaded active running Network Name Resolution
  systemd-timesyncd.service   loaded active running Network Time Synchronization
  systemd-udevd.service       loaded active running Rule-based Manager for Device Events and Files
  unattended-upgrades.service loaded active running Unattended Upgrades Shutdown
  user@0.service              loaded active running User Manager for UID 0

Legend: LOAD   → Reflects whether the unit definition was properly loaded.
        ACTIVE → The high-level unit activation state, i.e. generalization of SUB.
        SUB    → The low-level unit activation state, values depend on unit type.

24 loaded units listed.

root@web:~# systemctl list-timers --all
ls -la /etc/cron.d /etc/cron.daily /etc/cron.weekly
crontab -l
dpkg-query -W nginx certbot fail2ban unattended-upgrades fastd 2>/dev/null
ufw status verbose
NEXT                            LEFT LAST                          PASSED UNIT                           ACTIVATES
Mon 2026-11-16 18:59:56 CET 3min 25s -                                  - systemd-tmpfiles-clean.timer   systemd-tmpfiles-clean.service
Mon 2026-11-16 21:39:26 CET 2h 42min Mon 2026-11-16 13:10:21 CET        - apt-daily.timer                apt-daily.service
Tue 2026-11-17 00:00:00 CET  5h 3min Mon 2026-11-16 00:00:31 CET        - dpkg-db-backup.timer           dpkg-db-backup.service
Tue 2026-11-17 00:00:00 CET  5h 3min Mon 2026-11-16 00:00:31 CET        - logrotate.timer                logrotate.service
Tue 2026-11-17 00:22:01 CET 5h 25min Mon 2026-11-16 04:54:21 CET        - certbot.timer                  certbot.service
Tue 2026-11-17 03:20:36 CET       8h Mon 2026-11-16 16:02:55 CET        - motd-news.timer                motd-news.service
Tue 2026-11-17 03:36:30 CET       8h Mon 2026-11-16 09:10:31 CET        - man-db.timer                   man-db.service
Tue 2026-11-17 06:58:33 CET      12h Mon 2026-11-16 06:00:59 CET        - apt-daily-upgrade.timer        apt-daily-upgrade.service
Tue 2026-11-17 18:50:01 CET      23h Mon 2026-11-16 18:50:01 CET 6min ago update-notifier-download.timer update-notifier-download.service
Sun 2026-11-22 03:10:25 CET   5 days Sun 2026-11-15 03:10:18 CET        - e2scrub_all.timer              e2scrub_all.service
Sun 2026-11-22 20:56:33 CET   6 days Fri 2026-11-13 09:11:21 CET        - update-notifier-motd.timer     update-notifier-motd.service
Mon 2026-11-23 01:23:08 CET   6 days Mon 2026-11-16 01:02:21 CET        - fstrim.timer                   fstrim.service
-                                  - -                                  - apport-autoreport.timer        apport-autoreport.service
-                                  - -                                  - phpsessionclean.timer          -
-                                  - -                                  - plocate-updatedb.timer         -
-                                  - -                                  - ua-timer.timer                 ua-timer.service

16 timers listed.
/etc/cron.d:
total 36
drwxr-xr-x   2 root root  4096 Oct  5  2024 .
drwxr-xr-x 120 root root 12288 Nov 14 06:21 ..
-rw-r--r--   1 root root   802 Apr 16  2023 certbot
-rw-r--r--   1 root root   201 Feb 14  2020 e2scrub_all
-rw-r--r--   1 root root   712 Jan 18  2018 php
-rw-r--r--   1 root root   102 Nov 16  2017 .placeholder
-rw-r--r--   1 root root   190 May 19  2019 popularity-contest

/etc/cron.daily:
total 60
drwxr-xr-x   2 root root  4096 Nov  6 06:05 .
drwxr-xr-x 120 root root 12288 Nov 14 06:21 ..
-rwxr-xr-x   1 root root   376 Nov 20  2017 apport
-rwxr-xr-x   1 root root  1478 Apr  8  2022 apt-compat
-rwxr-xr-x   1 root root   314 Jan 17  2018 aptitude
-rwxr-xr-x   1 root root   355 Dec 29  2017 bsdmainutils.dpkg-remove
-rwxr-xr-x   1 root root   123 Dec  5  2021 dpkg
-rwxr-xr-x   1 root root   377 Jan 21  2019 logrotate
-rwxr-xr-x   1 root root  1395 Mar 29  2024 man-db
-rw-r--r--   1 root root   102 Nov 16  2017 .placeholder
-rwxr-xr-x   1 root root   652 Dec  7  2020 plocate
-rwxr-xr-x   1 root root  5638 Jul 18  2023 popularity-contest

/etc/cron.weekly:
total 24
drwxr-xr-x   2 root root  4096 Oct  5  2024 .
drwxr-xr-x 120 root root 12288 Nov 14 06:21 ..
-rwxr-xr-x   1 root root  1055 Mar 29  2024 man-db
-rw-r--r--   1 root root   102 Nov 16  2017 .placeholder
no crontab for root
certbot 2.9.0-1
fail2ban        1.0.2-3ubuntu0.1
fastd   22-4build2
nginx   1.24.0-2ubuntu7.19
unattended-upgrades     2.9.1+nmu4ubuntu1
Status: inactive

root@web:~# cat /etc/nginx/sites-available/install
server {
    listen 80;
    listen [::]:80;

    server_name install.freifunk-suedholstein.de;

    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;

    server_name install.freifunk-suedholstein.de;

    root /var/www/firmware-selector;
    index index.html;

    autoindex on;
    access_log off;

    location = /favicon.ico {
        log_not_found off;
        access_log off;
    }

    location = /robots.txt {
        allow all;
        log_not_found off;
        access_log off;
    }

    location / {
        try_files $uri $uri/ =404;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico)$ {
        expires max;
        log_not_found off;
    }

    ssl_certificate /etc/letsencrypt/live/install.freifunk-suedholstein.de/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/install.freifunk-suedholstein.de/privkey.pem;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;

    ssl_dhparam /etc/nginx/dhparam.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers on;

    add_header Strict-Transport-Security max-age=15768000;

    ssl_stapling on;
    ssl_stapling_verify on;

}

