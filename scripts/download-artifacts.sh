#!/bin/bash

# =============================================================================
# Script: download-artifacts.sh
# Author: Pete Ward
# Created: 2025-04-19
# Description: Downloads Elastic and endpoint artifacts for specified versions,
#              bundles them, and optionally builds an Nginx image to serve them.
# License: MIT
# =============================================================================
set -euo pipefail

# === Preflight Check ===
preflight_check() {
  # Bash version >= 4
  if [[ -z "${BASH_VERSINFO[0]:-}" || ${BASH_VERSINFO[0]} -lt 4 ]]; then
    error "Bash 4.0 or higher is required."
  fi

  # Required commands
  for cmd in curl tar; do
    if ! command -v "$cmd" &>/dev/null; then
      error "$cmd is not installed."
    fi
  done

  # One of nerdctl, podman, or docker
  if ! command -v nerdctl &>/dev/null && ! command -v podman &>/dev/null && ! command -v docker &>/dev/null; then
    error "One of nerdctl, podman, or docker must be installed."
  fi

  # Endpoint artifacts tools: jq and zcat
  for cmd in jq zcat; do
    if ! command -v "$cmd" &>/dev/null; then
      warn "$cmd is not installed; endpoint artifacts may fail."
    fi
  done

  # Network access checks
  for url in https://artifacts.elastic.co/ https://artifacts.security.elastic.co/; do
    if ! curl -sSf --head --max-time 10 "$url" &>/dev/null; then
      warn "Cannot reach $url; network or proxy issue."
    fi
  done
}

# === Colors and Logging ===
GREEN='\033[1;32m'; YELLOW='\033[1;33m'; RED='\033[1;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}$1${NC}"; }
warn()  { echo -e "${YELLOW}$1${NC}"; }
error(){ echo -e "${RED}$1${NC}"; exit 1; }

# === Usage ===
usage(){
  echo -e "${YELLOW}Usage:${NC} $0 [ -h | --help ] [--versions 7.x.x,8.x.x,...] [--bundle] [--build-nginx-image] [--destination dir] [--bundle-name file.tar.gz] [--nginx-image-tag name:tag] [--update]"
  echo
  echo "Actions:"
  echo "  --versions            Download artifacts for these versions (comma-separated or repeatable)"
  echo "  --bundle              Create tar.gz bundle from destination directory"
  echo "  --build-nginx-image   Build custom Nginx image with those artifacts"
  echo
  echo "Options:"
  echo "  --destination         Directory for raw files (default: ./artifacts-bundle)"
  echo "  --bundle-name         Name of final tar.gz (default: elastic-artifacts-assets-<timestamp>.tar.gz)"
  echo "  --nginx-image-tag     Tag for the built Nginx image (default: elastic-artifacts-nginx:latest)"
  echo "  --update              Do NOT clear destination folder; keep existing files (default: overwrite)"
  echo "  -h, --help            Show help and exit"
  exit 1
}

# === Defaults ===
OUTPUT_DIR="./artifacts-bundle"
VERSIONS=()
DO_BUNDLE=false
BUNDLE_NAME=""
DO_BUILD_NGINX_IMAGE=false
NGINX_IMAGE_TAG="elastic-artifacts-nginx:latest"
UPDATE_EXISTING=false

# Run Preflight
preflight_check

# === Parse Flags ===
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help) usage ;;      
    --versions)
      shift
      while [[ $# -gt 0 && $1 != --* ]]; do
        IFS=',' read -ra NEW <<< "$1"
        for v in "${NEW[@]}"; do
          VERSIONS+=("$v")
        done
        shift
      done
      ;;
    --bundle)             DO_BUNDLE=true; shift ;;    
    --build-nginx-image)  DO_BUILD_NGINX_IMAGE=true; shift ;;    
    --destination)        shift; [[ -n "${1-}" ]] || usage; OUTPUT_DIR="$1"; shift ;;    
    --bundle-name)        shift; [[ -n "${1-}" ]] || usage; BUNDLE_NAME="$1"; shift ;;    
    --nginx-image-tag)    shift; [[ -n "${1-}" ]] || usage; NGINX_IMAGE_TAG="$1"; shift ;;    
    --update)             UPDATE_EXISTING=true; shift ;;    
    *)                    error "Unknown option: $1" ;;  
  esac
done

# === Validate ===
if ! $DO_BUNDLE && ! $DO_BUILD_NGINX_IMAGE && [ ${#VERSIONS[@]} -eq 0 ]; then
  error "Must specify at least --versions, --bundle, or --build-nginx-image"
  usage
fi

if $DO_BUNDLE && [ -z "$BUNDLE_NAME" ]; then
  BUNDLE_NAME="elastic-artifacts-assets-$(date +%Y%m%d%H%M%S).tar.gz"
fi

# Record start time
START=$(date +%s)
MANIFEST="$OUTPUT_DIR/manifest.json"

# === Functions ===
generate_artifacts(){
  local v=$1
  binaries=(
    "apm-server/apm-server"
    "beats/auditbeat/auditbeat" "beats/elastic-agent/elastic-agent" "beats/filebeat/filebeat"
    "beats/heartbeat/heartbeat" "beats/metricbeat/metricbeat" "beats/osquerybeat/osquerybeat" "beats/packetbeat/packetbeat"
    "cloudbeat/cloudbeat"
    "endpoint-dev/endpoint-security"
    "fleet-server/fleet-server"
    "prodfiler/pf-host-agent" "prodfiler/pf-elastic-collector" "prodfiler/pf-elastic-symbolizer"
  )
  platforms=("linux-arm64.tar.gz" "linux-x86_64.tar.gz" "darwin-x86_64.tar.gz" "darwin-aarch64.tar.gz" "windows-x86_64.zip")
  exts=("" ".sha512" ".asc")
  for b in "${binaries[@]}"; do
    for p in "${platforms[@]}"; do
      for e in "${exts[@]}"; do
        echo "https://artifacts.elastic.co/downloads/${b}-${v}-${p}${e}"
      done
    done
  done
}

download_asset(){
  local url=$1 dest=$2
  mkdir -p "$(dirname "$dest")"
  if [[ -f "$dest" ]]; then
    echo "Already exists: $dest"
  else
    echo "Downloading: $url"
    if ! curl -sSfL "$url" -o "$dest"; then
      warn "Failed: $url"
    fi
  fi
}

write_manifest(){
  local pathDir=$1 file=$2
  echo "  { \"path\":\"$pathDir\",\"file\":\"$file\" }," >> "$MANIFEST"
}

# === Download Artifacts ===
if [ ${#VERSIONS[@]} -gt 0 ]; then
  info "Versions to download: ${VERSIONS[*]}"
  if ! $UPDATE_EXISTING; then
    info "Clearing destination: $OUTPUT_DIR"
    rm -rf "$OUTPUT_DIR"
  fi
  mkdir -p "$OUTPUT_DIR"
  echo "[" > "$MANIFEST"

  for v in "${VERSIONS[@]}"; do
    info "Processing version: $v"
    generate_artifacts "$v" | while IFS= read -r url; do
      path=${url#*downloads/}
      pathDir=${path%/*}
      file=${path##*/}
      dest="$OUTPUT_DIR/$pathDir/$file"
      download_asset "$url" "$dest"
      [[ "$file" == *.tar.gz ]] && write_manifest "$pathDir" "$file"
    done || true

    # Endpoint artifacts
    info "Downloading endpoint artifacts for version $v"
    endpoint_manifest="endpoint/manifest/artifacts-$v.zip"
    url_manifest="https://artifacts.security.elastic.co/downloads/$endpoint_manifest"
    download_asset "$url_manifest" "$OUTPUT_DIR/$endpoint_manifest"

    if command -v jq &>/dev/null && command -v zcat &>/dev/null; then
      zcat -q "$OUTPUT_DIR/$endpoint_manifest" |
        jq -r '.artifacts | to_entries[] | .value.relative_url' |
        while IFS= read -r rel; do
          rel_path="${rel#/downloads/}"
          full="https://artifacts.security.elastic.co${rel}"
          dest="$OUTPUT_DIR/$rel_path"
          download_asset "$full" "$dest"
          [[ "$rel_path" == *.tar.gz ]] && write_manifest "$(dirname "$rel_path")" "$(basename "$rel_path")"
        done || true
    else
      warn "jq or zcat missing; cannot process endpoint manifest"
    fi
  done

  sed -i '$ s/},/}/' "$MANIFEST"
  echo "]" >> "$MANIFEST"
fi

# === Bundle ===
if $DO_BUNDLE; then
  info "Creating bundle: $BUNDLE_NAME"
  tar -czf "$BUNDLE_NAME" -C "$OUTPUT_DIR" .
  info "Bundle created at $(pwd)/$BUNDLE_NAME"
fi

# === Build Nginx Image ===
if $DO_BUILD_NGINX_IMAGE; then
  info "Building custom Nginx image: $NGINX_IMAGE_TAG"
  CTX="$OUTPUT_DIR/nginx-image"
  rm -rf "$CTX"
  mkdir -p "$CTX/downloads"
  for d in "$OUTPUT_DIR"/*; do
    [[ -d $d ]] || continue
    [[ "$(basename "$d")" == "nginx-image" ]] && continue
    cp -R "$d" "$CTX/downloads/"
  done

  cat > "$CTX/default.conf" <<'EOF'
server {
  listen 80;
  server_name _;
  root /usr/share/nginx/html;
  location /downloads/ {
    autoindex on;
    etag on;
    try_files $uri $uri/ =404;
  }
  location = / {
    return 302 /downloads/;
  }
}
EOF

  cat > "$CTX/Dockerfile" <<'EOF'
FROM nginx:stable
COPY default.conf /etc/nginx/conf.d/default.conf
COPY downloads/ /usr/share/nginx/html/downloads/
EOF

  if command -v nerdctl &>/dev/null; then
    info "Using nerdctl to build"
    nerdctl build -t "$NGINX_IMAGE_TAG" "$CTX"
  elif command -v podman &>/dev/null; then
    info "Using podman to build"
    podman build -t "$NGINX_IMAGE_TAG" "$CTX"
  else
    info "Using docker to build"
    docker build -t "$NGINX_IMAGE_TAG" "$CTX"
  fi
fi

# === Completion Time ===
END=$(date +%s)
info "Total time: $((END-START))s"
