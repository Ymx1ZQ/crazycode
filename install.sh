#!/usr/bin/env bash
# crazycode installer
# Usage: curl -fsSL https://raw.githubusercontent.com/Ymx1ZQ/crazycode/main/install.sh | bash

set -euo pipefail

R='\033[0;31m' Y='\033[0;33m' C='\033[0;36m' W='\033[1;37m' D='\033[2;37m' G='\033[0;32m' X='\033[0m'

_info()    { echo -e "  ${C}→${X} $*"; }
_ok()      { echo -e "  ${G}✓${X} $*"; }
_warn()    { echo -e "  ${Y}⚠${X} $*"; }
_err()     { echo -e "  ${R}✗${X} $*" >&2; }
_section() { echo -e "\n  ${D}────────────────────────────────${X}\n  ${W}$*${X}"; }

_has() { command -v "$1" >/dev/null 2>&1; }

_ask() {
  local label="$1" desc="$2"
  echo -e "\n  ${W}${label}${X}  ${D}${desc}${X}"
  local ans
  read -rp "  Install? [Y/n] " ans
  [[ ! "$ans" =~ ^[Nn]$ ]]
}

_ensure_pipx() {
  if ! _has pipx; then
    _warn "pipx not found."
    echo -e "  ${D}Install it with:  sudo apt install pipx${X}"
    if _ask "pipx" "required by aider — install it now?"; then
      sudo apt install -y pipx
      pipx ensurepath
    else
      return 1
    fi
  fi
}

_ensure_npm() {
  if ! _has npm; then
    _warn "npm / Node.js not found."
    echo -e "  ${D}Recommended: install via nvm — https://github.com/nvm-sh/nvm${X}"
    echo -e "  ${D}  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash${X}"
    echo -e "  ${D}  nvm install --lts${X}"
    return 1
  fi
}

_install_npm_tool() {
  local label="$1" pkg="$2"
  if _ensure_npm; then
    npm i -g "$pkg"
    _ok "$label installed"
  else
    _warn "$label skipped (npm unavailable)"
  fi
}

# ─── phase 1: install crazycode ───────────────────────────────────────────────

_section "⚡ CRAZYCODE — installer"

if ! _has git; then
  _err "git is required but not found. Install it first:"
  _err "  sudo apt install git"
  exit 1
fi

CRAZYCODE_DIR="$HOME/.crazycode"

if [ -d "$CRAZYCODE_DIR/.git" ]; then
  _info "~/.crazycode already exists — updating..."
  git -C "$CRAZYCODE_DIR" fetch --quiet
  git -C "$CRAZYCODE_DIR" reset --hard "@{u}" >/dev/null 2>&1
else
  _info "Cloning crazycode into ~/.crazycode..."
  git clone https://github.com/Ymx1ZQ/crazycode.git "$CRAZYCODE_DIR"
fi
_ok "crazycode installed"

BASHRC="$HOME/.bashrc"
SOURCE_LINE="source ~/.crazycode/crazycode.sh"
touch "$BASHRC"
if ! grep -qF "$SOURCE_LINE" "$BASHRC"; then
  printf '\n%s\n' "$SOURCE_LINE" >> "$BASHRC"
  _ok "Added to ~/.bashrc"
else
  _ok "~/.bashrc already sourced — nothing to change"
fi

# ─── phase 2: optional tools ──────────────────────────────────────────────────

_section "Optional tools"
echo -e "  ${D}All tools install by default — press n to skip any.${X}"

if _ask "caffeine" "keeps the screen on — prevents display sleep (apt)"; then
  sudo apt install -y caffeine
  _ok "caffeine installed"
fi

if _ask "aider" "AI pair programmer in the terminal (pipx install aider-chat)"; then
  if _ensure_pipx; then
    pipx install aider-chat
    _ok "aider installed"
  else
    _warn "aider skipped (pipx unavailable)"
  fi
fi

if _ask "claude code" "Anthropic's official AI CLI (curl installer)"; then
  curl -fsSL https://claude.ai/install.sh | bash
  _ok "claude code installed"
fi

if _ask "opencode" "AI coding tool by SST (npm i -g opencode-ai@latest)"; then
  _install_npm_tool "opencode" "opencode-ai@latest"
fi

if _ask "codex" "OpenAI's AI coding CLI (npm i -g @openai/codex)"; then
  _install_npm_tool "codex" "@openai/codex"
fi

# ─── done ─────────────────────────────────────────────────────────────────────

echo
_ok "All done!"
_info "Reload your shell or run:  source ~/.bashrc"
_info "Then type:  crazycode"
echo
