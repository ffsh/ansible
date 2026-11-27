#!/bin/sh

metric_dir=/var/lib/node_exporter/textfile_collector
metric_file=$metric_dir/certbot_renewal.prom
tmp_file=$(mktemp "$metric_dir/.certbot_renewal.prom.XXXXXX")

success=0
if certbot renew --dry-run --nginx --no-random-sleep-on-renew >/dev/null 2>&1; then
    success=1
fi

cat > "$tmp_file" <<EOF
# HELP ffsh_certbot_renewal_success Whether the latest Certbot renewal dry-run succeeded.
# TYPE ffsh_certbot_renewal_success gauge
ffsh_certbot_renewal_success $success
EOF

chmod 0644 "$tmp_file"
mv -f "$tmp_file" "$metric_file"
