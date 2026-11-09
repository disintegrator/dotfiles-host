#!/usr/bin/env bash

set -euf -o pipefail

log() {
  local level=$1 message=$2
  shift 2
  gum log --time timeonly --structured --level "$level" "$message" "$@"
}

info() {
  log info "$@"
}
warn() {
  log warn "$@"
}
err() {
  log error "$@"
}

iron_secrets() {
  local github_token openrouter_key

  local ca_cnf=~/.config/iron-proxy/iron-ca.cnf
  local ca_key=~/.local/share/iron-proxy/iron-ca.key
  local ca_crt=~/.local/share/iron-proxy/iron-ca.crt

  if [[ ! -f "$ca_key" ]]; then
    mkdir -p ~/.local/share/iron-proxy
    umask 077
    openssl req -x509 -new -sha256 -days 730 \
      -newkey ec -pkeyopt ec_paramgen_curve:P-256 -pkeyopt ec_param_enc:named_curve -nodes \
      -config "$ca_cnf" \
      -keyout "$ca_key" -out "$ca_crt"
    chmod 400 "$ca_key" "$ca_crt"
    info "Created iron proxy CA" key "$ca_key" cert "$ca_crt" config "$ca_cnf"
  else
    warn "iron-proxy CA already exists, skipping" key "$ca_key"
  fi

  github_token=$(
    gum input \
      --password \
      --header "GitHub PAT - allows agents to work with GitHub CLI and git"
  ) || return 1

  openrouter_key=$(
    gum input \
      --password \
      --header "OpenRouter Key - allows agents to make inference requests"
  ) || return 1

  mise set --global --env iron \
    GITHUB_TOKEN="$github_token" \
    OPENROUTER_KEY="$openrouter_key"
}

iron_secrets

mkcert -install

cat <<'EOF' | gum format --type markdown
# Next steps

## Tailscale

1. Install Tailscale: https://tailscale.com/download
2. Log in
3. Re-render the iron-proxy config with this machine's Tailscale IP and restart it:

  ```sh
  mise dot apply
  launchctl kickstart -k gui/$(id -u)/dev.mise.iron-proxy
  ```

## Virtual machine

1. Install a virtual machine manager:
  - OrbStack: https://orbstack.dev/
  - VMPal: https://vmpal.com/
2. Setup a Debian or Ubuntu LTS VM
3. Run the following in that VM

  ```sh
  curl -fsSL https://mise.run | sh
  mise boostrap --adopt disintegrator/dotfiles-sandbox-debian
  ```
EOF

