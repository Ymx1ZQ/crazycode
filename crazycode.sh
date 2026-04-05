#!/usr/bin/env bash

crazycode() {
  # Colors
  local B='\033[1m' D='\033[2m' X='\033[0m'
  local BR='\033[1;31m'  # bold red
  local BG='\033[1;32m'  # bold green
  local BY='\033[1;33m'  # bold yellow
  local BC='\033[1;36m'  # bold cyan
  local BW='\033[1;37m'  # bold white

  local items=("aider" "claudecode" "opencode" "codex")
  local cmds=("aider" "claude" "opencode" "codex")
  local descriptions=("AI pair programmer" "Anthropic" "SST" "OpenAI")
  local launch_args=(
    "--yes-always"
    "--dangerously-skip-permissions"
    ""
    "--sandbox danger-full-access --ask-for-approval never"
  )
  local num_items=${#items[@]}
  local selected=0
  local prev_selected=-1

  # ── awake mode state ──────────────────────────────────────────────
  local sleep_masked=0 caffeine_on=0 lid_ignored=0 lock_disabled=0

  check_sleep() {
    systemctl is-enabled sleep.target 2>/dev/null | grep -q masked && sleep_masked=1 || sleep_masked=0
  }

  check_caffeine() {
    caffeine_on=0
    pgrep -f caffeine-indicator >/dev/null 2>&1 && caffeine_on=1
    if command -v xset &>/dev/null && [ -n "$DISPLAY" ]; then
      local dpms_status
      dpms_status=$(xset q 2>/dev/null | grep -i "DPMS is" | tr -d '[:space:]')
      [[ "${dpms_status,,}" == *"disabled"* ]] && caffeine_on=1
    fi
  }

  check_lid() {
    local val
    val=$(grep -i '^HandleLidSwitch=' /etc/systemd/logind.conf 2>/dev/null | tail -1 | cut -d= -f2 | tr -d '[:space:]')
    [[ "${val,,}" == "ignore" ]] && lid_ignored=1 || lid_ignored=0
  }

  check_lock() {
    lock_disabled=0
    if command -v gsettings &>/dev/null && [ -n "$DISPLAY$WAYLAND_DISPLAY" ]; then
      local idle lock
      idle=$(gsettings get org.gnome.desktop.session idle-delay 2>/dev/null)
      lock=$(gsettings get org.gnome.desktop.screensaver lock-enabled 2>/dev/null)
      [[ "$idle" == "uint32 0" ]] && [[ "$lock" == "false" ]] && lock_disabled=1
    fi
    if command -v kreadconfig5 &>/dev/null; then
      local lock
      lock=$(kreadconfig5 --group Daemon --key Autolock 2>/dev/null)
      [[ "$lock" == "false" ]] && lock_disabled=1
    fi
  }

  check_awake() {
    check_sleep
    check_caffeine
    check_lid
    check_lock
  }

  is_awake() {
    [[ $sleep_masked -eq 1 && $caffeine_on -eq 1 && $lid_ignored -eq 1 && $lock_disabled -eq 1 ]]
  }

  enable_awake() {
    sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target >/dev/null 2>&1

    if ! command -v caffeine-indicator &>/dev/null; then
      sudo apt install -y caffeine >/dev/null 2>&1
    fi
    if ! pgrep -f caffeine-indicator >/dev/null 2>&1; then
      caffeine-indicator >/dev/null 2>&1 &
      disown
    fi

    if command -v xset &>/dev/null && [ -n "$DISPLAY" ]; then
      xset s off -dpms 2>/dev/null
    fi

    sudo sed -i 's/^#\?HandleLidSwitch=.*/HandleLidSwitch=ignore/' /etc/systemd/logind.conf 2>/dev/null
    sudo grep -q '^HandleLidSwitch=' /etc/systemd/logind.conf 2>/dev/null \
      || echo 'HandleLidSwitch=ignore' | sudo tee -a /etc/systemd/logind.conf >/dev/null
    sudo systemctl kill -s HUP systemd-logind 2>/dev/null

    if command -v gsettings &>/dev/null && [ -n "$DISPLAY$WAYLAND_DISPLAY" ]; then
      gsettings set org.gnome.desktop.session idle-delay 0 2>/dev/null
      gsettings set org.gnome.desktop.screensaver lock-enabled false 2>/dev/null
    fi
    if command -v kwriteconfig5 &>/dev/null; then
      kwriteconfig5 --group Daemon --key Autolock false 2>/dev/null
    fi

    check_awake
  }

  disable_awake() {
    sudo systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target >/dev/null 2>&1
    pkill -f caffeine-indicator 2>/dev/null

    if command -v xset &>/dev/null && [ -n "$DISPLAY" ]; then
      xset s on +dpms 2>/dev/null
    fi

    sudo sed -i 's/^#\?HandleLidSwitch=.*/HandleLidSwitch=suspend/' /etc/systemd/logind.conf 2>/dev/null
    sudo systemctl kill -s HUP systemd-logind 2>/dev/null

    if command -v gsettings &>/dev/null && [ -n "$DISPLAY$WAYLAND_DISPLAY" ]; then
      gsettings set org.gnome.desktop.session idle-delay 300 2>/dev/null
      gsettings set org.gnome.desktop.screensaver lock-enabled true 2>/dev/null
    fi
    if command -v kwriteconfig5 &>/dev/null; then
      kwriteconfig5 --group Daemon --key Autolock true 2>/dev/null
    fi

    check_awake
  }

  # ── drawing helpers ──────────────────────────────────────────────
  get_color() {
    case "$1" in
      aider)      printf "%s" "$BR" ;;
      claudecode) printf "%s" "$BC" ;;
      opencode)   printf "%s" "$BW" ;;
      codex)      printf "%s" "$BY" ;;
      *)          printf "%s" "$D" ;;
    esac
  }

  awake_count() {
    local count=0
    [[ $sleep_masked -eq 1 ]] && ((count++))
    [[ $caffeine_on -eq 1 ]] && ((count++))
    [[ $lid_ignored -eq 1 ]] && ((count++))
    [[ $lock_disabled -eq 1 ]] && ((count++))
    echo "$count"
  }

  get_awake_line() {
    local count
    count=$(awake_count)
    if [[ $count -eq 4 ]]; then
      printf "  ${BW}[c]${X} ${D}camomile${X} ${D}🌿${X}       ${BG}[awake mode on]${X}"
    elif [[ $count -gt 0 ]]; then
      printf "  ${BW}[c]${X} ${BG}coffeeshot${X} ${BG}☕${X}     ${BY}[partial ${count}/4]${X}"
    else
      printf "  ${BW}[c]${X} ${BG}coffeeshot${X} ${BG}☕${X}     ${D}[awake mode off]${X}"
    fi
  }

  _launch_tool() {
    local idx=$1
    shift
    local tool="${items[$idx]}"
    local cmd="${cmds[$idx]}"
    local color
    color=$(get_color "$tool")

    if ! command -v "$cmd" &>/dev/null; then
      printf "\n  ${BR}${B}✗${X}  ${BW}${tool}${X} ${D}is not installed.${X}\n"
      printf "  ${D}Run the installer to set it up:${X}\n"
      printf "  ${D}  curl -fsSL https://raw.githubusercontent.com/Ymx1ZQ/crazycode/main/install.sh | bash${X}\n\n"
      return 1
    fi

    printf "\n  ${color}${B}Launching ${tool}...${X}\n\n"

    # shellcheck disable=SC2086 — args is from hardcoded array, word splitting is intentional
    ${cmd} ${launch_args[$idx]} "$@"
  }

  _print_status() {
    check_awake
    local on="${BG}✓${X}" off="${BR}✗${X}"
    printf "\n  ${BW}${B}awake mode status${X}\n"
    printf "  ───────────────────────────\n"
    printf "  sleep masked:    %b\n" "$( [[ $sleep_masked -eq 1 ]] && echo "$on" || echo "$off" )"
    printf "  caffeine/dpms:   %b\n" "$( [[ $caffeine_on -eq 1 ]] && echo "$on" || echo "$off" )"
    printf "  lid ignored:     %b\n" "$( [[ $lid_ignored -eq 1 ]] && echo "$on" || echo "$off" )"
    printf "  lock disabled:   %b\n" "$( [[ $lock_disabled -eq 1 ]] && echo "$on" || echo "$off" )"
    printf "  ───────────────────────────\n"
    if is_awake; then
      printf "  ${BG}${B}awake mode: ON${X}\n\n"
    else
      printf "  ${D}awake mode: OFF${X}\n\n"
    fi
  }

  _print_help() {
    printf "\n  ${BR}${B}⚡  CRAZYCODE${X}  ${D}— AI coding launcher${X}\n\n"
    printf "  ${BW}Usage:${X}  crazycode [command] [args...]\n\n"
    printf "  ${BW}Commands:${X}\n"
    printf "    ${BR}aider${X}          Launch aider (--yes-always)\n"
    printf "    ${BC}claudecode${X}     Launch Claude Code (--dangerously-skip-permissions)\n"
    printf "    ${BW}opencode${X}       Launch opencode\n"
    printf "    ${BY}codex${X}          Launch codex (--sandbox danger-full-access)\n"
    printf "    ${BG}coffeeshot${X}     Toggle awake mode on/off\n"
    printf "    ${D}status${X}         Show awake mode status\n\n"
    printf "  ${D}Run without arguments to open the interactive TUI.${X}\n\n"
  }

  _find_tool_index() {
    local name="$1" i
    for i in "${!items[@]}"; do
      [[ "${items[$i]}" == "$name" ]] && echo "$i" && return 0
    done
    return 1
  }

  # ── CLI mode: handle subcommands ─────────────────────────────────
  if [[ $# -gt 0 ]]; then
    local subcmd="$1"
    shift
    local idx
    if idx=$(_find_tool_index "$subcmd"); then
      _launch_tool "$idx" "$@"
      return $?
    fi
    case "$subcmd" in
      coffeeshot)
        check_awake
        if is_awake; then
          disable_awake
          printf "  ${D}🌿 camomile — awake mode OFF${X}\n"
        else
          enable_awake
          printf "  ${BG}☕ coffeeshot — awake mode ON${X}\n"
        fi
        return 0
        ;;
      status) _print_status ; return 0 ;;
      --help|-h|help) _print_help ; return 0 ;;
      *)
        printf "  ${BR}Unknown command:${X} %s\n" "$subcmd"
        _print_help
        return 1
        ;;
    esac
  fi

  # ── TUI mode ─────────────────────────────────────────────────────
  _cleanup() {
    echo -ne "\033[?25h"
    stty echo 2>/dev/null
  }
  trap _cleanup EXIT INT TERM

  # Row layout:
  #   1  (blank)
  #   2  ⚡ CRAZYCODE
  #   3  ━━━━━━━━━━━━
  #   4… items (4 + idx)
  #   4+N separator
  #   5+N awake line
  #   6+N separator
  #   7+N help
  #   8+N warning
  #   9+N cursor

  draw_line() {
    local idx=$1 is_selected=$2
    local item="${items[$idx]}"
    local cmd="${cmds[$idx]}"
    local color
    color=$(get_color "$item")
    local installed_mark
    if command -v "$cmd" &>/dev/null; then
      installed_mark="${BG}✓${X}"
    else
      installed_mark="${BR}✗${X}"
    fi

    local num=$((idx + 1))
    local row=$((4 + idx))
    echo -ne "\033[${row};1H\033[K"
    if [ "$is_selected" -eq 1 ]; then
      printf "  ${BW}${B}▶${X} ${B}${color}%-15s${X} ${D}%s${X}  %b" "$item" "${descriptions[$idx]}" "$installed_mark"
    else
      printf "  ${D}${num}${X} ${color}%-15s${X} ${D}%s${X}  %b" "$item" "${descriptions[$idx]}" "$installed_mark"
    fi
  }

  draw_menu() {
    local i
    for i in "${!items[@]}"; do
      draw_line "$i" 0
    done
  }

  draw_awake() {
    local row=$((5 + num_items))
    echo -ne "\033[${row};1H\033[K"
    get_awake_line
  }

  draw_all() {
    clear
    printf "\n"
    printf "  ${BR}${B}⚡  CRAZYCODE${X}\n"
    printf "  ${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${X}\n"
    draw_menu
    printf "\033[$((4 + num_items));1H  ${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${X}\n"
    draw_awake
    printf "\033[$((6 + num_items));1H  ${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${X}\n"
    printf "\033[$((7 + num_items));1H  ${D}↑↓/1-4 select  ·  enter launch  ·  c toggle  ·  q quit${X}\n"
    printf "\033[$((8 + num_items));1H  ${BY}⚠${X}  ${D}all tools launch without asking permission${X}\n"
    echo -ne "\033[$((9 + num_items));1H"
    draw_line "$selected" 1
  }

  check_awake
  draw_all
  trap 'draw_all' WINCH

  # ── input loop ────────────────────────────────────────────────────
  while true; do
    local key=""
    read -rsn1 key

    case "$key" in
      $'\x1b')
        read -rsn2 -t 0.1 key2
        case "$key2" in
          '[A')
            prev_selected=$selected
            selected=$(( (selected - 1 + num_items) % num_items ))
            draw_line "$prev_selected" 0
            draw_line "$selected" 1
            ;;
          '[B')
            prev_selected=$selected
            selected=$(( (selected + 1) % num_items ))
            draw_line "$prev_selected" 0
            draw_line "$selected" 1
            ;;
        esac
        ;;
      '')
        break
        ;;
      c)
        local prompt_row=$((9 + num_items))
        echo -ne "\033[${prompt_row};1H\033[K"
        sudo -v
        echo -ne "\033[${prompt_row};1H\033[K"
        if is_awake; then
          disable_awake
        else
          enable_awake
        fi
        draw_awake
        echo -ne "\033[${prompt_row};1H"
        ;;
      [1-4])
        local num_idx=$((key - 1))
        if [[ $num_idx -lt $num_items ]]; then
          selected=$num_idx
          break
        fi
        ;;
      q)
        clear
        return 0
        ;;
    esac
  done

  clear
  _launch_tool "$selected" "$@"
}

# ── bash completion ──────────────────────────────────────────────────
_crazycode_completions() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  COMPREPLY=( $(compgen -W "aider claudecode opencode codex coffeeshot status --help" -- "$cur") )
}
# NOTE: completion words match items array + extra commands; update if items change
complete -F _crazycode_completions crazycode

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  crazycode "$@"
fi
