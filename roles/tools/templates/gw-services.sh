#!/bin/bash

set -eu

ACTION="${1:-check}"

FASTD_SVC="fastd@ffsh.service"
WG_SVC="wg-quick@exit.service"
BAT_IF="bat0"
WG_IF="exit"

declare -a FAILURES=()

if [ -t 1 ]; then
  C_GREEN=$'\033[0;32m'
  C_RED=$'\033[0;31m'
  C_YELLOW=$'\033[1;33m'
  C_RESET=$'\033[0m'
else
  C_GREEN=''
  C_RED=''
  C_YELLOW=''
  C_RESET=''
fi

ok() {
  printf '%s[OK]%s   %s\n' "$C_GREEN" "$C_RESET" "$1"
}

fail() {
  printf '%s[FAIL]%s %s\n' "$C_RED" "$C_RESET" "$1"
}

info() {
  printf '[INFO] %s\n' "$1"
}

add_failure() {
  FAILURES+=("$1")
}

format_age() {
  local sec="$1"
  if (( sec < 60 )); then
    printf '%s seconds ago' "$sec"
  elif (( sec < 3600 )); then
    printf '%s minutes ago' "$((sec / 60))"
  elif (( sec < 86400 )); then
    printf '%s hours ago' "$((sec / 3600))"
  else
    printf '%s days ago' "$((sec / 86400))"
  fi
}

check_batman_neighbors() {
  if ! command -v batctl >/dev/null 2>&1; then
    fail "batctl not installed"
    return 1
  fi

  if ! bat_output=$(batctl meshif "$BAT_IF" n 2>/dev/null); then
    fail "batman query failed: batctl meshif $BAT_IF n"
    return 1
  fi

  ffsh_count=$(printf '%s\n' "$bat_output" | awk '$1 == "ffsh-mesh" { c++ } END { print c + 0 }')

  if (( ffsh_count > 2 )); then
    ok "Batman neighbors via ffsh-mesh: $ffsh_count"
    return 0
  fi

  fail "Batman neighbors via ffsh-mesh too low: $ffsh_count (need > 2)"
  return 1
}

check_batctl_version() {
  if ! command -v batctl >/dev/null 2>&1; then
    fail "batctl not installed"
    return 1
  fi

  if ! version_output=$(batctl -v 2>/dev/null); then
    fail "batctl -v command failed"
    return 1
  fi

  batctl_ver=$(printf '%s\n' "$version_output" | awk '{ print $2 }')
  batman_ver=$(printf '%s\n' "$version_output" | sed -n 's/.*\[batman-adv: \([^]]*\).*/\1/p')

  if [ -z "$batctl_ver" ] || [ -z "$batman_ver" ]; then
    fail "Could not parse batctl version output: $version_output"
    return 1
  fi

  if [ "$batctl_ver" = "$batman_ver" ]; then
    ok "batctl and batman-adv versions match: $batctl_ver"
    return 0
  fi

  fail "Version mismatch - batctl: $batctl_ver, batman-adv: $batman_ver"
  return 1
}

check_wg_latest_handshake() {
  if ! command -v wg >/dev/null 2>&1; then
    fail "wg not installed"
    return 1
  fi

  if ! wg_data=$(wg show "$WG_IF" latest-handshakes 2>/dev/null); then
    fail "WireGuard interface $WG_IF not available"
    return 1
  fi

  latest_ts=$(printf '%s\n' "$wg_data" | awk 'BEGIN{m=0} { if ($2 > m) m = $2 } END{ print m }')
  if [ -z "$latest_ts" ] || [ "$latest_ts" -eq 0 ]; then
    fail "WireGuard latest handshake: never"
    return 1
  fi

  now_ts=$(date +%s)
  age=$((now_ts - latest_ts))
  if (( age < 0 )); then
    age=0
  fi

  ok "WireGuard latest handshake: $(format_age "$age")"
  return 0
}

check_mullvad_exit() {
  if ! command -v curl >/dev/null 2>&1; then
    fail "curl not installed, cannot verify Mullvad exit"
    return 1
  fi

  if ! command -v jq >/dev/null 2>&1; then
    fail "jq not installed, cannot verify Mullvad exit"
    return 1
  fi

  curl_output=$(curl -s --interface "$WG_IF" https://am.i.mullvad.net/json 2>/dev/null) || {
    fail "Mullvad exit check failed: curl error"
    return 1
  }

  is_exit=$(printf '%s\n' "$curl_output" | jq -r '.mullvad_exit_ip // false' 2>/dev/null) || {
    fail "Mullvad exit check failed: jq parse error"
    return 1
  }

  if [ "$is_exit" = "true" ]; then
    city=$(printf '%s\n' "$curl_output" | jq -r '.city // "unknown"' 2>/dev/null)
    hostname=$(printf '%s\n' "$curl_output" | jq -r '.mullvad_exit_ip_hostname // "unknown"' 2>/dev/null)
    ok "Mullvad exit is in $city, gateway: $hostname"
    return 0
  fi

  fail "Mullvad exit check: not connected to Mullvad"
  return 1
}

is_service_active() {
  systemctl is-active --quiet "$1"
}

print_separator() {
  printf '%s========================================%s\n' "$1" "$C_RESET"
}

{% raw %}
print_summary() {
  local num_failures
  num_failures=${#FAILURES[@]}

  if (( num_failures == 0 )); then
    echo
    print_separator "$C_GREEN"
    printf '%sAll systems operational!%s\n' "$C_GREEN" "$C_RESET"
    printf '%sHave a nice day! 🚀%s\n' "$C_GREEN" "$C_RESET"
    print_separator "$C_GREEN"
    echo
    return 0
  fi

  echo
  print_separator "$C_RED"
  printf '%s⚠ OVERALL STATUS: FAILED%s\n' "$C_RED" "$C_RESET"
  print_separator "$C_RED"
  printf '\n%sFailures detected:%s\n' "$C_RED" "$C_RESET"

  local i
  for i in "${!FAILURES[@]}"; do
    printf '  • %s\n' "${FAILURES[$i]}"
  done

  printf '\n%sRecommendations:%s\n' "$C_RED" "$C_RESET"

  local failure_str
  failure_str="${FAILURES[*]}"

  if [[ "$failure_str" =~ "Batman neighbors" ]]; then
    printf '\n  %sBatman mesh connectivity issue:%s\n' "$C_YELLOW" "$C_RESET"
    printf '    - Check if other gateways are reachable\n'
    printf '    - Verify fastd tunnel is active\n'
    printf '    - Check batman interface: ip link show bat0\n'
  fi

  if [[ "$failure_str" =~ "Version mismatch" ]]; then
    printf '\n  %sbatman-adv version mismatch:%s\n' "$C_YELLOW" "$C_RESET"
    printf '    - Option 1: Rebuild DKMS module: /root/fix-batman.sh\n'
    printf '    - Option 2: Reboot gateway to reload kernel module\n'
    printf '    - Option 3: Check system logs: journalctl -u batman-adv | head -20\n'
  fi

  if [[ "$failure_str" =~ "$FASTD_SVC" ]]; then
    printf '\n  %sFastd service issue:%s\n' "$C_YELLOW" "$C_RESET"
    printf '    - Restart service: systemctl restart %s\n' "$FASTD_SVC"
    printf '    - Check logs: journalctl -u %s -n 50\n' "$FASTD_SVC"
    printf '    - Verify fastd key directory: ls -la /etc/fastd/ffsh/\n'
  fi

  if [[ "$failure_str" =~ "WireGuard" ]]; then
    printf '\n  %sWireGuard tunnel issue:%s\n' "$C_YELLOW" "$C_RESET"
    printf '    - Restart service: systemctl restart %s\n' "$WG_SVC"
    printf '    - Check connection: wg show exit\n'
    printf '    - Verify exit interface: ip addr show exit\n'
    printf '    - Check WireGuard config: cat /etc/wireguard/exit.conf\n'
  fi

  if [[ "$failure_str" =~ "Mullvad" ]]; then
    printf '\n  %sMullvad exit verification failed:%s\n' "$C_YELLOW" "$C_RESET"
    printf '    - Ensure %s is active and connected\n' "$WG_SVC"
    printf '    - Verify Mullvad wireguard config is installed\n'
    printf '    - Check DNS resolution: nslookup am.i.mullvad.net\n'
    printf '    - Test connectivity: ping -I exit 8.8.8.8\n'
    printf '    - Manual test: curl -s --interface exit https://am.i.mullvad.net/json | jq .\n'
  fi

  printf '\n%sNeeded action:%s\n' "$C_YELLOW" "$C_RESET"
  printf '  1. Investigate and fix failures listed above\n'
  printf '  2. Run: %s check\n' "$(basename "$0")"
  printf '  3. If unclear, check detailed logs: journalctl -xe\n'
  print_separator "$C_RED"
  echo
  return 1
}
{% endraw %}

check_status() {
  FAILURES=()

  if ! check_batman_neighbors; then
    add_failure "Batman neighbors via ffsh-mesh failed"
  fi

  if ! check_batctl_version; then
    add_failure "batctl/batman-adv version mismatch"
  fi

  if is_service_active "$FASTD_SVC"; then
    ok "Service $FASTD_SVC is active"
  else
    fail "Service $FASTD_SVC is NOT active"
    add_failure "$FASTD_SVC not running"
  fi

{% if enable_wireguard_exit | default(false) %}
  if ! check_wg_latest_handshake; then
    add_failure "WireGuard handshake outdated or never connected"
  fi

  if ! check_mullvad_exit; then
    add_failure "Mullvad exit IP verification failed"
  fi

  if is_service_active "$WG_SVC"; then
    ok "Service $WG_SVC is active"
  else
    fail "Service $WG_SVC is NOT active"
    add_failure "$WG_SVC not running"
  fi
{% else %}
  info "WireGuard exit is disabled for this host"
{% endif %}

  print_summary
  return $?
}

restart_services() {
{% if enable_wireguard_exit | default(false) %}
  info "Restart order: $FASTD_SVC -> $WG_SVC"
{% else %}
  info "Restart order: $FASTD_SVC"
{% endif %}

  info "Restarting $FASTD_SVC"
  systemctl restart "$FASTD_SVC"

{% if enable_wireguard_exit | default(false) %}
  info "Restarting $WG_SVC"
  systemctl restart "$WG_SVC"
{% endif %}

  info "Waiting 15 seconds for services to stabilize and batman to populate neighbors..."
  sleep 15

  info "Running status check"
  echo
  check_status
}

case "$ACTION" in
  check)
    check_status
    ;;
  restart)
    restart_services
    ;;
  help|-h|--help)
    printf 'Usage: %s [check|restart]\n' "$0"
    printf '  check   Default. Show compact service/interface status\n'
    printf '  restart Restart services in order, then run check\n'
    ;;
  *)
    printf 'Unknown action: %s\n' "$ACTION" >&2
    printf 'Use: %s [check|restart]\n' "$0" >&2
    exit 2
    ;;
esac
