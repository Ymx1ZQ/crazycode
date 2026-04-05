#!/usr/bin/env bash
# crazycode installer
# Usage: curl -fsSL https://raw.githubusercontent.com/Ymx1ZQ/crazycode/main/install.sh | bash
#   --all     install everything without prompting
#   --silent  suppress interactive output (errors only)

set -euo pipefail

R='\033[0;31m' Y='\033[0;33m' C='\033[0;36m' W='\033[1;37m' D='\033[2;37m' G='\033[0;32m' X='\033[0m'

ALL=0 SILENT=0
for arg in "$@"; do
  case "$arg" in
    --all)    ALL=1 ;;
    --silent) SILENT=1 ;;
  esac
done

_info()    { [[ $SILENT -eq 1 ]] && return; echo -e "  ${C}→${X} $*"; }
_ok()      { [[ $SILENT -eq 1 ]] && return; echo -e "  ${G}✓${X} $*"; }
_warn()    { echo -e "  ${Y}⚠${X} $*"; }
_err()     { echo -e "  ${R}✗${X} $*" >&2; }
_section() { [[ $SILENT -eq 1 ]] && return; echo -e "\n  ${D}────────────────────────────────${X}\n  ${W}$*${X}"; }

_has() { command -v "$1" >/dev/null 2>&1; }

_ask() {
  [[ $ALL -eq 1 ]] && return 0
  local label="$1" desc="$2"
  echo -e "\n  ${W}${label}${X}  ${D}${desc}${X}"
  local ans
  read -rp "  Install? [Y/n] " ans
  [[ ! "$ans" =~ ^[Nn]$ ]]
}

# Track install results for summary
declare -a TOOL_NAMES=() TOOL_RESULTS=()

_track() {
  TOOL_NAMES+=("$1")
  if _has "$2"; then
    TOOL_RESULTS+=("ok")
  else
    TOOL_RESULTS+=("fail")
  fi
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

# Detect shell and source in the right rc file
SHELL_NAME=$(basename "${SHELL:-bash}")
case "$SHELL_NAME" in
  zsh)  RC_FILE="$HOME/.zshrc" ;;
  *)    RC_FILE="$HOME/.bashrc" ;;
esac

SOURCE_LINE="source ~/.crazycode/crazycode.sh"
touch "$RC_FILE"
if ! grep -qF "$SOURCE_LINE" "$RC_FILE"; then
  printf '\n%s\n' "$SOURCE_LINE" >> "$RC_FILE"
  _ok "Added to ~/${RC_FILE##*/}"
else
  _ok "~/${RC_FILE##*/} already sourced — nothing to change"
fi

# ─── phase 2: optional tools ──────────────────────────────────────────────────

_section "Optional tools"
if [[ $ALL -eq 0 && $SILENT -eq 0 ]]; then
  echo -e "  ${D}All tools install by default — press n to skip any.${X}"
fi

if _ask "caffeine" "keeps the screen on — prevents display sleep (apt)"; then
  sudo apt install -y caffeine
  _ok "caffeine installed"
fi
_track "caffeine" "caffeine-indicator"

if _ask "aider" "AI pair programmer in the terminal (pipx install aider-chat)"; then
  if _ensure_pipx; then
    pipx install aider-chat
    _ok "aider installed"
  else
    _warn "aider skipped (pipx unavailable)"
  fi
fi
_track "aider" "aider"

if _ask "claude code" "Anthropic's official AI CLI (curl installer)"; then
  curl -fsSL https://claude.ai/install.sh | bash
  _ok "claude code installed"
fi
_track "claude code" "claude"

if _ask "opencode" "AI coding tool by SST (npm i -g opencode-ai@latest)"; then
  _install_npm_tool "opencode" "opencode-ai@latest"
fi
_track "opencode" "opencode"

if _ask "codex" "OpenAI's AI coding CLI (npm i -g @openai/codex)"; then
  _install_npm_tool "codex" "@openai/codex"
fi
_track "codex" "codex"

# ─── summary ─────────────────────────────────────────────────────────────────

if [[ $SILENT -eq 0 ]]; then
  echo
  _section "Summary"
  for i in "${!TOOL_NAMES[@]}"; do
    if [[ "${TOOL_RESULTS[$i]}" == "ok" ]]; then
      echo -e "  ${G}✓${X}  ${TOOL_NAMES[$i]}"
    else
      echo -e "  ${R}✗${X}  ${TOOL_NAMES[$i]}"
    fi
  done
  echo
fi

_ok "All done!"
_info "Reload your shell or run:  source ~/${RC_FILE##*/}"
_info "Then type:  crazycode"
echo
