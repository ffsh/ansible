# Plan: Add Alertmanager with Blackbox reachability alerts → Telegram

## TL;DR
Add a new `alertmanager` role (installed via apt, same pattern as `prometheus`/`blackbox_exporter`), wire it into the existing (currently commented-out) `alerting:`/`rule_files:` sections of `roles/prometheus/templates/prometheus.yml.j2`, add a Prometheus alert rule that fires when a `blackbox-http` probe fails for 5m, and route Alertmanager notifications to a Telegram channel via a bot (native `telegram_configs` receiver, no extra webhook service needed). Telegram bot token + chat ID go into vault-encrypted `group_vars/secrets.yml` as `vault_secrets.alertmanager.telegram_bot_token` / `vault_secrets.alertmanager.telegram_chat_id` (user will add these manually via `ansible-vault edit`).

## Steps

### Phase 1: New `alertmanager` role
1. Create `roles/alertmanager/tasks/main.yml` — mirrors `roles/blackbox_exporter/tasks/main.yml` pattern:
   - `ansible.builtin.apt` install `prometheus-alertmanager`, `update_cache: true`
   - `ansible.builtin.template` deploy `alertmanager.yml.j2` → `/etc/prometheus/alertmanager.yml`, owner/group root, mode 0644, `notify: Restart alertmanager`
   - `ansible.builtin.systemd` enable+start `prometheus-alertmanager`
2. Create `roles/alertmanager/handlers/main.yml` — handler `Restart alertmanager` (systemd restart `prometheus-alertmanager`), same shape as `roles/blackbox_exporter/handlers/main.yml`.
3. Create `roles/alertmanager/templates/alertmanager.yml.j2`:
   - `route:` default receiver = `telegram`, `group_by: ['alertname', 'instance']`, `group_wait`/`group_interval`/`repeat_interval` reasonable defaults (e.g. 30s/5m/3h)
   - `receivers:` one receiver `telegram` using native `telegram_configs`
   - Listen address bound to localhost only

### Phase 2: Alert rule for blackbox reachability
4. Create `roles/prometheus/templates/alert_rules.yml.j2` with a rule group:
   - `groups: - name: blackbox` containing rule `alert: ProbeFailed`, `expr: probe_success == 0`, `for: 5m`, `labels: severity: critical`, `annotations: summary/description` referencing `$labels.instance` and `$labels.job`
5. Update `roles/prometheus/tasks/main.yml` — add a task templating `alert_rules.yml.j2` → `/etc/prometheus/alert_rules.yml` (owner/group root, mode 0644) before the restart task.

### Phase 3: Wire Prometheus → Alertmanager
6. Edit `roles/prometheus/templates/prometheus.yml.j2`:
   - Uncomment `alerting.alertmanagers[0].static_configs[0].targets` and set to `["127.0.0.1:9093"]`
   - Uncomment `rule_files:` and set to `["/etc/prometheus/alert_rules.yml"]`

### Phase 4: Playbook wiring
7. Edit `setup.yml` monitoring play — add `{role: alertmanager, tags: "alertmanager"}` to the `roles:` list.

### Phase 5: Secrets (manual, user-performed)
8. User runs `ansible-vault edit group_vars/secrets.yml` and adds:
   ```yaml
   vault_secrets:
     alertmanager:
       telegram_bot_token: "<token from BotFather>"
       telegram_chat_id: <numeric chat/channel id, negative for channels>
   ```

## Relevant files
- `roles/alertmanager/tasks/main.yml` — new, install + configure + start
- `roles/alertmanager/handlers/main.yml` — new, restart handler
- `roles/alertmanager/templates/alertmanager.yml.j2` — new, route + telegram receiver
- `roles/prometheus/templates/alert_rules.yml.j2` — new, `ProbeFailed` rule on `probe_success == 0`
- `roles/prometheus/tasks/main.yml` — add template task for alert_rules.yml
- `roles/prometheus/templates/prometheus.yml.j2` — uncomment/fill `alerting:` and `rule_files:` sections
- `setup.yml` — add `alertmanager` role to monitoring play
- `group_vars/secrets.yml` — user adds `vault_secrets.alertmanager.telegram_bot_token`/`telegram_chat_id` manually via `ansible-vault edit`

## Verification
1. `ansible-playbook setup.yml --syntax-check` after edits
2. `ansible-playbook setup.yml --limit monitoring --tags alertmanager,prometheus --check --diff` dry run
3. Deploy for real: `ansible-playbook setup.yml --limit monitoring --tags alertmanager,prometheus`
4. On monitoring host: `systemctl status prometheus-alertmanager`, `curl -s http://127.0.0.1:9093/-/healthy`
5. Prometheus UI → Status → Rules: confirm `ProbeFailed` rule loaded; Status → Alertmanagers: confirm target `127.0.0.1:9093` shown as up
6. Trigger a real test: temporarily break reachability for one target and confirm a Telegram message arrives in the channel after ~5m
7. `promtool check config` / `promtool check rules` on rendered files if promtool available on monitoring host

## Decisions
- Alertmanager installed via apt (`prometheus-alertmanager` Debian package) for consistency with existing prometheus/blackbox_exporter roles — no version pinning in `group_vars/versions.yml`.
- Alert firing delay: `for: 5m` on `probe_success == 0`.
- Telegram integration uses Alertmanager's native `telegram_configs` receiver (built into Alertmanager since v0.25) rather than a separate telegram-webhook bridge service.
- Scope: only blackbox probe reachability alerts for now. Not adding alerts for node_exporter/gateway/ffshmon/disk/CPU etc. in this pass.
- Alertmanager bound to localhost (127.0.0.1:9093), reached by Prometheus on the same monitoring host — not exposed externally.

## Further Considerations
1. Telegram bot/channel setup guidance (creating bot via @BotFather, obtaining numeric chat ID for a channel) provided as part of implementation.
