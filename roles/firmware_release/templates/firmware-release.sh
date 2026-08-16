#!/usr/bin/env bash
set -euo pipefail

OWNER="{{ firmware_release_owner }}"
REPO="{{ firmware_release_repo }}"
ROOT_DIR="{{ firmware_release_root }}"
API_BASE="https://api.github.com/repos/${OWNER}/${REPO}/releases"

TMP_DIR=""
PUBLISH_SUCCEEDED=false

cleanup() {
  if [[ "$PUBLISH_SUCCEEDED" == true && -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi
}

trap cleanup EXIT

is_tty() {
  [[ -t 1 ]]
}

say() {
  local msg="${1:-}"
  printf '%s\n' "$msg"
}

ok() {
  say "✅ $1"
}

warn() {
  say "⚠️  $1"
}

err() {
  say "❌ $1" >&2
}

section() {
  say
  say "📦 $1"
}

spinner() {
  local pid="$1"
  local text="$2"
  local completed="$3"
  local total="$4"
  local progress_file="$5"
  local -a frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local frame=0
  local percent=0

  if ! is_tty; then
    wait "$pid"
    return
  fi

  while kill -0 "$pid" 2>/dev/null; do
    local live_percent
    live_percent="$(tr '\r' '\n' < "$progress_file" | grep -oE '[0-9]+(\.[0-9]+)?%' | tail -n 1 | cut -d. -f1 | tr -d '%' || true)"
    if [[ "$live_percent" =~ ^[0-9]+$ ]]; then
      percent="$live_percent"
    elif [[ "$total" -gt 0 ]]; then
      percent=$((completed * 100 / total))
    fi
    printf '\r\033[K%s %s [%3d%%]' "${frames[frame]}" "$text" "$percent"
    frame=$(( (frame + 1) % 10 ))
    sleep 0.1
  done

  wait "$pid" || return 1
  percent=100
  printf '\r\033[K%s %s [%3d%%]\n' '✓' "$text" 100
}

ensure_layout() {
  mkdir -p "$ROOT_DIR"

  local testing_path="$ROOT_DIR/testing"
  if [[ -L "$testing_path" ]]; then
    local target
    target="$(readlink -f "$testing_path")"
    if [[ "$target" != "$ROOT_DIR"/* ]]; then
      warn "$testing_path points outside the firmware root, removing symlink"
      rm -f "$testing_path"
    fi
  elif [[ -e "$testing_path" ]]; then
    warn "$testing_path is not a symlink, deleting for safety"
    rm -rf "$testing_path"
  fi

  local rc_path="$ROOT_DIR/rc"
  if [[ -L "$rc_path" ]]; then
    local target
    target="$(readlink -f "$rc_path")"
    if [[ "$target" != "$ROOT_DIR"/* ]]; then
      warn "$rc_path points outside the firmware root, removing symlink"
      rm -f "$rc_path"
    fi
  elif [[ -e "$rc_path" ]]; then
    warn "$rc_path is not a symlink, deleting for safety"
    rm -rf "$rc_path"
  fi

  if [[ -L "$ROOT_DIR/stable" ]]; then
    local target
    target="$(readlink -f "$ROOT_DIR/stable")"
    if [[ "$target" != "$ROOT_DIR"/* ]]; then
      warn "$ROOT_DIR/stable points outside the firmware root, removing symlink"
      rm -f "$ROOT_DIR/stable"
    fi
  fi
}

write_testing_version() {
  local version="$1"
  printf '%s\n' "$version" > "$ROOT_DIR/testing/.release-version"
}

read_stage_version() {
  local stage="$1"
  if [[ -f "$ROOT_DIR/$stage/.release-version" ]]; then
    tr -d '\n' < "$ROOT_DIR/$stage/.release-version"
  fi
}

fetch_release_json() {
  local endpoint="$1"

  local http_code
  http_code="$(curl -sS -o "$TMP_DIR/release.json" -w '%{http_code}' "$endpoint")"
  if [[ "$http_code" -lt 200 || "$http_code" -ge 300 ]]; then
    err "GitHub API call failed with HTTP $http_code ($endpoint)"
    return 1
  fi
}

resolve_release() {
  local version="${1:-latest}"

  if [[ "$version" == "latest" ]]; then
    fetch_release_json "$API_BASE/latest"
  else
    fetch_release_json "$API_BASE/tags/$version"
  fi

  local tag
  tag="$(jq -r '.tag_name // empty' "$TMP_DIR/release.json")"
  if [[ -z "$tag" ]]; then
    err "No release tag found in response"
    return 1
  fi

  echo "$tag"
}

download_assets() {
  section "Downloading release archives"

  mapfile -t assets < <(jq -r '.assets[] | select(.name | test("^[0-9].*\\.(tar(\\.(gz|bz2|xz))?|tgz|tbz2|txz|zip|part[0-9A-Za-z]+)$")) | @base64' "$TMP_DIR/release.json")

  local assets_count
  assets_count="$(printf '%s\n' "${assets[@]}" | sed '/^$/d' | wc -l | tr -d ' ')"
  if [[ "$assets_count" -eq 0 ]]; then
    err "No matching firmware archive assets found in release"
    return 1
  fi

  mkdir -p "$TMP_DIR/downloads"

  local asset_index=0
  for entry in "${assets[@]}"; do
    local json
    local name
    local url
    local expected_size
    local output
    local progress_file

    json="$(printf '%s' "$entry" | base64 -d)"
    name="$(jq -r '.name' <<<"$json")"
    url="$(jq -r '.browser_download_url' <<<"$json")"
    expected_size="$(jq -r '.size // 0' <<<"$json")"
    output="$TMP_DIR/downloads/$name"
    progress_file="$TMP_DIR/downloads/$name.progress"

    if [[ -f "$output" && "$expected_size" -gt 0 ]]; then
      local current_size
      current_size="$(stat -c '%s' "$output")"
      if [[ "$current_size" -eq "$expected_size" ]]; then
        asset_index=$((asset_index + 1))
        continue
      elif [[ "$current_size" -gt "$expected_size" ]]; then
        rm -f "$output"
      fi
    fi

    : > "$progress_file"
    (
      curl -fL --continue-at - --retry 5 --retry-all-errors --retry-delay 2 \
        --progress-bar --stderr "$progress_file" "$url" -o "$output"
    ) &
    if ! spinner "$!" "Downloading $name" "$asset_index" "$assets_count" "$progress_file"; then
      cat "$progress_file" >&2
      rm -f "$progress_file"
      return 1
    fi
    rm -f "$progress_file"
    asset_index=$((asset_index + 1))
  done
}

combine_parts() {
  section "Combining split archives"

  local found_parts=false
  while IFS= read -r part; do
    found_parts=true
    local base
    local output

    base="$(basename "$part")"
    base="${base%.part*}"
    output="$TMP_DIR/downloads/$base"

    if [[ -e "$output" ]]; then
      continue
    fi

    cat "$TMP_DIR/downloads/${base}.part"* > "$output"
    rm -f "$TMP_DIR/downloads/${base}.part"*
    ok "Combined parts into $base"
  done < <(find "$TMP_DIR/downloads" -maxdepth 1 -type f -name '*.part*' | sort)

  if [[ "$found_parts" == false ]]; then
    ok "No split archives found"
  fi
}

unpack_assets() {
  section "Unpacking release"

  local extract_dir="$TMP_DIR/extract"
  mkdir -p "$extract_dir"

  shopt -s nullglob
  local archives=(
    "$TMP_DIR"/downloads/*.tar
    "$TMP_DIR"/downloads/*.tar.gz
    "$TMP_DIR"/downloads/*.tgz
    "$TMP_DIR"/downloads/*.tar.bz2
    "$TMP_DIR"/downloads/*.tbz2
    "$TMP_DIR"/downloads/*.tar.xz
    "$TMP_DIR"/downloads/*.txz
    "$TMP_DIR"/downloads/*.zip
  )
  shopt -u nullglob

  local archives_count
  archives_count="$(printf '%s\n' "${archives[@]}" | sed '/^$/d' | wc -l | tr -d ' ')"
  if [[ "$archives_count" -eq 0 ]]; then
    err "No unpackable archives available"
    return 1
  fi

  local archive_index=0
  for archive in "${archives[@]}"; do
    case "$archive" in
      *.zip)
        unzip -oq "$archive" -d "$extract_dir"
        ;;
      *)
        tar -xf "$archive" -C "$extract_dir"
        ;;
    esac
    rm -f "$archive"
    archive_index=$((archive_index + 1))
    if is_tty; then
      printf '\r\033[KUnpacking release [%3d%%] %s\n' "$((archive_index * 100 / archives_count))" "$(basename "$archive")"
    else
      ok "Unpacked and removed $(basename "$archive")"
    fi
  done

  rm -rf "$ROOT_DIR/testing"

  shopt -s dotglob nullglob
  local extracted_items=("$extract_dir"/*)
  shopt -u dotglob nullglob

  local extracted_count
  extracted_count="$(printf '%s\n' "${extracted_items[@]}" | sed '/^$/d' | wc -l | tr -d ' ')"
  if [[ "$extracted_count" -eq 0 ]]; then
    err "Archive extraction produced no files"
    return 1
  fi

  if [[ "$extracted_count" -eq 1 && -d "${extracted_items[0]}" ]]; then
    local extracted_dir_name
    extracted_dir_name="$(basename "${extracted_items[0]}")"
    if [[ "$extracted_dir_name" =~ ^[0-9]{4}\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      mv "${extracted_items[0]}" "$ROOT_DIR/testing"
      rm -rf "$extract_dir"
      ln -sfn "$ROOT_DIR/testing" "$ROOT_DIR/rc"
      ok "Updated testing and rc"
      return 0
    fi
  fi

  mkdir -p "$ROOT_DIR/testing"
  mv "${extracted_items[@]}" "$ROOT_DIR/testing"/
  rm -rf "$extract_dir"

  ln -sfn "$ROOT_DIR/testing" "$ROOT_DIR/rc"

  ok "Updated testing and rc"
}

version_numbers() {
  local version="$1"
  version="${version#v}"
  IFS='.' read -r major minor patch extra <<<"$version"
  echo "${major:-0} ${minor:-0} ${patch:-0} ${extra:-0}"
}

ask_confirmation() {
  local prompt="$1"
  read -r -p "$prompt [y/N]: " answer
  [[ "$answer" =~ ^[Yy]$ ]]
}

promote() {
  section "Promoting testing to stable"

  if [[ -L "$ROOT_DIR/testing" ]]; then
    err "testing is a symlink; refusing to promote a symlinked testing target"
    return 1
  fi

  if [[ ! -d "$ROOT_DIR/testing" ]]; then
    err "testing is missing"
    return 1
  fi

  local current_tag next_tag
  current_tag="$(read_stage_version "stable")"
  next_tag="$(read_stage_version "testing")"

  if [[ -z "$next_tag" ]]; then
    err "Missing $ROOT_DIR/testing/.release-version"
    return 1
  fi

  if [[ -n "$current_tag" ]]; then
    local cur_major cur_minor cur_patch cur_extra
    local next_major next_minor next_patch next_extra

    read -r cur_major cur_minor cur_patch cur_extra < <(version_numbers "$current_tag")
    read -r next_major next_minor next_patch next_extra < <(version_numbers "$next_tag")

    if [[ "$cur_major" != "$next_major" || "$cur_minor" != "$next_minor" ]]; then
      warn "Major/minor changed: $current_tag -> $next_tag"
      if ! ask_confirmation "Bigger change detected. Have you created an archive copy and want to proceed?"; then
        err "Promotion cancelled"
        return 1
      fi
    fi
  fi

  if ! ask_confirmation "Are you sure you want to promote testing to stable?"; then
    err "Promotion cancelled"
    return 1
  fi

  if [[ -L "$ROOT_DIR/rc" ]]; then
    rm -f "$ROOT_DIR/rc"
  elif [[ -e "$ROOT_DIR/rc" ]]; then
    rm -rf "$ROOT_DIR/rc"
  fi

  if [[ -L "$ROOT_DIR/testing" ]]; then
    rm -f "$ROOT_DIR/testing"
  elif [[ -e "$ROOT_DIR/testing" ]]; then
    rm -rf "$ROOT_DIR/testing"
  fi

  if [[ -L "$ROOT_DIR/stable" ]]; then
    rm -f "$ROOT_DIR/stable"
  elif [[ -e "$ROOT_DIR/stable" ]]; then
    rm -rf "$ROOT_DIR/stable"
  fi

  mv "$ROOT_DIR/testing" "$ROOT_DIR/stable"
  ln -sfn "$ROOT_DIR/stable" "$ROOT_DIR/testing"
  ln -sfn "$ROOT_DIR/stable" "$ROOT_DIR/rc"

  ok "Promotion complete"
}

publish() {
  local version="${1:-latest}"

  section "Preparing workspace"
  ensure_layout

  TMP_DIR="$ROOT_DIR/.firmware-release-work"
  mkdir -p "$TMP_DIR/downloads"

  local resolved_tag
  resolved_tag="$(resolve_release "$version")"
  ok "Using release $resolved_tag"

  download_assets
  combine_parts
  unpack_assets
  write_testing_version "$resolved_tag"
  PUBLISH_SUCCEEDED=true
}

usage() {
  cat <<USAGE
Usage:
  firmware-release.sh publish [tag]    Download latest (default) or specific release and update testing/rc
  firmware-release.sh promote          Promote testing to stable
USAGE
}

main() {
  local command="${1:-}"

  case "$command" in
    publish)
      publish "${2:-latest}"
      ;;
    promote)
      promote
      ;;
    ""|-h|--help|help)
      usage
      ;;
    *)
      err "Unknown command: $command"
      usage
      return 1
      ;;
  esac
}

main "$@"
