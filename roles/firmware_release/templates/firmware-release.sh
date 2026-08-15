#!/usr/bin/env bash
set -euo pipefail

OWNER="{{ firmware_release_owner }}"
REPO="{{ firmware_release_repo }}"
ROOT_DIR="{{ firmware_release_root }}"
SAFE_SPACE="{{ firmware_release_safe_space }}"
API_BASE="https://api.github.com/repos/${OWNER}/${REPO}/releases"

TMP_DIR=""

cleanup() {
  if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi
}

trap cleanup EXIT

is_tty() {
  [[ -t 1 ]]
}

say() {
  local msg="$1"
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
  local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local i=0

  if ! is_tty; then
    wait "$pid"
    return
  fi

  while kill -0 "$pid" 2>/dev/null; do
    printf '\r%s %s' "${spin:i++%${#spin}:1}" "$text"
    sleep 0.1
  done

  wait "$pid"
  printf '\r%-80s\r' ""
}

ensure_layout() {
  mkdir -p "$ROOT_DIR" "$SAFE_SPACE"

  for link_name in testing rc stable; do
    local path="$ROOT_DIR/$link_name"

    if [[ -L "$path" ]]; then
      local target
      target="$(readlink -f "$path")"
      if [[ "$target" == "$SAFE_SPACE"/* ]]; then
        continue
      fi
      warn "$path points outside safe space, removing symlink"
      rm -f "$path"
      continue
    fi

    if [[ -e "$path" ]]; then
      warn "$path is not a symlink, deleting for safety"
      rm -rf "$path"
    fi
  done

  if [[ -L "$ROOT_DIR/testing" ]]; then
    rm -f "$ROOT_DIR/testing"
  fi

  if [[ -L "$ROOT_DIR/rc" ]]; then
    rm -f "$ROOT_DIR/rc"
  fi
}

write_testing_version() {
  local version="$1"
  printf '%s\n' "$version" > "$SAFE_SPACE/testing/.release-version"
}

read_stage_version() {
  local stage="$1"
  if [[ -f "$SAFE_SPACE/$stage/.release-version" ]]; then
    tr -d '\n' < "$SAFE_SPACE/$stage/.release-version"
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

  mapfile -t assets < <(jq -r '.assets[] | select(.name | test("\\.(tar(\\.(gz|bz2|xz))?|tgz|tbz2|txz|zip|part[0-9A-Za-z]+)$")) | @base64' "$TMP_DIR/release.json")

  if [[ ${#assets[@]} -eq 0 ]]; then
    err "No archive assets found in release"
    return 1
  fi

  mkdir -p "$TMP_DIR/downloads"

  for entry in "${assets[@]}"; do
    local json
    local name
    local url

    json="$(printf '%s' "$entry" | base64 -d)"
    name="$(jq -r '.name' <<<"$json")"
    url="$(jq -r '.browser_download_url' <<<"$json")"

    (
      curl -fL --silent --show-error "$url" -o "$TMP_DIR/downloads/$name"
    ) &
    spinner "$!" "Downloading $name"
    ok "Downloaded $name"
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

  if [[ ${#archives[@]} -eq 0 ]]; then
    err "No unpackable archives available"
    return 1
  fi

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
    ok "Unpacked and removed $(basename "$archive")"
  done

  rm -rf "$SAFE_SPACE/testing"
  mkdir -p "$SAFE_SPACE/testing"
  shopt -s dotglob nullglob
  local extracted_items=("$extract_dir"/*)
  shopt -u dotglob nullglob
  if [[ ${#extracted_items[@]} -eq 0 ]]; then
    err "Archive extraction produced no files"
    return 1
  fi
  mv "${extracted_items[@]}" "$SAFE_SPACE/testing"/
  rm -rf "$extract_dir"

  ln -sfn "$SAFE_SPACE/testing" "$ROOT_DIR/testing"
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

  local testing_target stable_target

  if [[ ! -L "$ROOT_DIR/testing" ]]; then
    err "testing is missing or not a symlink"
    return 1
  fi

  testing_target="$(readlink -f "$ROOT_DIR/testing")"
  if [[ "$testing_target" != "$SAFE_SPACE"/* ]]; then
    err "testing points outside safe space"
    return 1
  fi

  local current_tag next_tag
  current_tag="$(read_stage_version "stable")"
  next_tag="$(read_stage_version "testing")"

  if [[ -n "$current_tag" && "$current_tag" != "stable" ]]; then
    local cur_major cur_minor cur_patch cur_extra
    local next_major next_minor next_patch next_extra

    read -r cur_major cur_minor cur_patch cur_extra < <(version_numbers "$current_tag")
    read -r next_major next_minor next_patch next_extra < <(version_numbers "$next_tag")

    if [[ "$cur_major" != "$next_major" || "$cur_minor" != "$next_minor" ]]; then
      warn "Major/minor changed: $current_tag -> $next_tag"
      if ! ask_confirmation "Bigger change detected. Archive copy created and proceed?"; then
        err "Promotion cancelled"
        return 1
      fi
    fi
  fi

  if ! ask_confirmation "Are you sure you want to promote testing to stable?"; then
    err "Promotion cancelled"
    return 1
  fi

  if [[ -z "$next_tag" ]]; then
    err "Missing $SAFE_SPACE/testing/.release-version"
    return 1
  fi

  rm -f "$ROOT_DIR/stable"
  rm -rf "$SAFE_SPACE/stable"
  mv "$SAFE_SPACE/testing" "$SAFE_SPACE/stable"

  ln -sfn "$SAFE_SPACE/stable" "$ROOT_DIR/stable"
  ln -sfn "$SAFE_SPACE/stable" "$ROOT_DIR/testing"
  ln -sfn "$ROOT_DIR/testing" "$ROOT_DIR/rc"

  ok "Promotion complete"
}

publish() {
  local version="${1:-latest}"

  section "Preparing workspace"
  ensure_layout

  TMP_DIR="$(mktemp -d)"

  local resolved_tag
  resolved_tag="$(resolve_release "$version")"
  ok "Using release $resolved_tag"

  download_assets
  combine_parts
  unpack_assets
  write_testing_version "$resolved_tag"
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
