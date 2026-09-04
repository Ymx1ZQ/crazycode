#!/usr/bin/env bash

_crazycode_main() {
  # Colors
  local B='\033[1m' D='\033[2m' X='\033[0m'
  local BR='\033[1;31m'  # bold red
  local BG='\033[1;32m'  # bold green
  local BY='\033[1;33m'  # bold yellow
  local BB='\033[1;34m'  # bold blue
  local BM='\033[1;35m'  # bold magenta
  local BC='\033[1;36m'  # bold cyan
  local BW='\033[1;37m'  # bold white
  local MO='\033[38;5;208m'  # orange for Muse

  local _crazycode_source_dir
  _crazycode_source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local _opencode_service="crazycode-opencode.service"
  local _opencode_url="http://127.0.0.1:4096"
  local _opencode_password=""
  local _opencode_runtime_path=""

  local items=("aider" "claude" "codex" "forge" "gemini" "goose" "muse" "opencode")
  local cmds=("aider" "claude" "codex" "forge" "gemini" "goose" "muse" "opencode")
  local descriptions=("Paul Gauthier" "Anthropic" "OpenAI" "Tailcall" "Google" "AAIF" "Meta" "SST")
  local launch_args=(
    "--yes-always"
    "--dangerously-skip-permissions"
    "--sandbox danger-full-access --ask-for-approval never"
    ""
    "--yolo"
    ""
    "--yolo"
    ""
  )
  # How each tool opens its own session chooser. An empty entry means "launch
  # plain": that tool picks the session from inside its TUI, and every flag we
  # could pass here would pin one session instead of letting the user choose.
  local resume_args=(
    "--restore-chat-history"  # aider: one chat log per directory, nothing to choose
    "--resume"                # claude: no value → interactive session picker
    ""                        # codex: `codex resume` subcommand, handled in _launch_tool
    ""                        # forge: /conversation shows the picker when given no id
    ""                        # gemini: /resume in-app; `--resume` with no value means "latest"
    "session --resume"        # goose: no picker — resumes the most recent session
    ""                        # muse: `muse resume` subcommand, handled in _launch_tool
    ""                        # opencode: session list in-app; -c would pin the last one
  )
  # Printed under "Resuming <tool>..." so the user knows where that tool keeps
  # its chooser — or why it hasn't got one.
  local resume_hints=(
    "reloading this folder's chat history — aider has no separate sessions"
    ""
    ""
    "type /conversation inside forge to pick a conversation"
    "type /resume inside gemini to browse saved conversations"
    "goose has no session picker — resuming the most recent session"
    ""
    "press ctrl+x then l inside opencode for the session list"
  )
  local num_items=${#items[@]}
  local selected=0
  local prev_selected=-1
  local _last_tool=-1

  # ── awake mode state ──────────────────────────────────────────────
  local sleep_masked=0 idle_inhibited=0 lid_ignored=0 lock_disabled=0

  check_sleep() {
    systemctl is-enabled sleep.target 2>/dev/null | grep -q masked && sleep_masked=1 || sleep_masked=0
  }

  check_idle_inhibit() {
    idle_inhibited=0
    systemd-inhibit --list --no-pager 2>/dev/null | grep -q crazycode-awake && idle_inhibited=1
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
    check_idle_inhibit
    check_lid
    check_lock
  }

  is_awake() {
    [[ $sleep_masked -eq 1 && $idle_inhibited -eq 1 && $lid_ignored -eq 1 && $lock_disabled -eq 1 ]]
  }

  enable_awake() {
    local snap="$HOME/.crazycode/awake.pre"
    # Snapshot what the machine looked like BEFORE we touch anything, so camomile
    # can put back exactly that instead of hardcoded defaults. Written only when
    # absent: a second enable must not overwrite it with already-awake values.
    if [[ ! -f "$snap" ]]; then
      mkdir -p "$(dirname "$snap")" 2>/dev/null
      {
        if systemctl is-enabled sleep.target 2>/dev/null | grep -q masked; then
          printf 'sleep_was_masked=1\n'
        else
          printf 'sleep_was_masked=0\n'
        fi
        printf 'pre_lid=%s\n' "$(grep -i '^HandleLidSwitch=' /etc/systemd/logind.conf 2>/dev/null | tail -1 | cut -d= -f2 | tr -d '[:space:]')"
        if command -v gsettings &>/dev/null && [ -n "$DISPLAY$WAYLAND_DISPLAY" ]; then
          printf 'pre_idle=%s\n' "$(gsettings get org.gnome.desktop.session idle-delay 2>/dev/null | awk '{print $NF}')"
          printf 'pre_lock=%s\n' "$(gsettings get org.gnome.desktop.screensaver lock-enabled 2>/dev/null)"
        fi
        if command -v kreadconfig5 &>/dev/null; then
          printf 'pre_kde_autolock=%s\n' "$(kreadconfig5 --group Daemon --key Autolock 2>/dev/null)"
        fi
      } > "$snap" 2>/dev/null
      chmod 600 "$snap" 2>/dev/null
    fi

    sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target >/dev/null 2>&1

    if ! systemd-inhibit --list --no-pager 2>/dev/null | grep -q crazycode-awake; then
      setsid systemd-inhibit --what=idle --who=crazycode-awake \
        --why="crazycode awake mode" --mode=block sleep infinity \
        </dev/null >/dev/null 2>&1 &
      disown
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
    local snap="$HOME/.crazycode/awake.pre"

    # The inhibitor is ours in every case: always drop it.
    pkill -f 'systemd-inhibit.*crazycode-awake' 2>/dev/null
    pkill -f caffeine-indicator 2>/dev/null

    if [[ ! -f "$snap" ]]; then
      # No snapshot: awake mode was enabled by an older version, or the state was
      # configured outside crazycode. Writing defaults here would destroy settings
      # we never saw, so skip lid, lock and idle entirely and say so.
      printf "  ${BY}no snapshot — lid, lock and idle left untouched${X}\n"
      check_awake
      return 0
    fi

    local sleep_was_masked=0 pre_lid="" pre_idle="" pre_lock="" pre_kde_autolock=""
    # shellcheck disable=SC1090
    . "$snap" 2>/dev/null

    # Only unmask what we masked: targets already masked before enabling stay masked.
    if [[ "$sleep_was_masked" != "1" ]]; then
      sudo systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target >/dev/null 2>&1
    fi

    if [[ -n "$pre_lid" ]]; then
      sudo sed -i "s/^#\\?HandleLidSwitch=.*/HandleLidSwitch=$pre_lid/" /etc/systemd/logind.conf 2>/dev/null
    else
      sudo sed -i '/^HandleLidSwitch=/d' /etc/systemd/logind.conf 2>/dev/null
    fi
    sudo systemctl kill -s HUP systemd-logind 2>/dev/null

    if command -v gsettings &>/dev/null && [ -n "$DISPLAY$WAYLAND_DISPLAY" ]; then
      [[ -n "$pre_idle" ]] && gsettings set org.gnome.desktop.session idle-delay "$pre_idle" 2>/dev/null
      [[ -n "$pre_lock" ]] && gsettings set org.gnome.desktop.screensaver lock-enabled "$pre_lock" 2>/dev/null
    fi
    if command -v kwriteconfig5 &>/dev/null && [[ -n "$pre_kde_autolock" ]]; then
      kwriteconfig5 --group Daemon --key Autolock "$pre_kde_autolock" 2>/dev/null
    fi

    rm -f "$snap" 2>/dev/null
    check_awake
  }

  # ── drawing helpers ──────────────────────────────────────────────
  get_color() {
    case "$1" in
      aider)    printf "%s" "$BR" ;;
      claude)   printf "%s" "$BC" ;;
      codex)    printf "%s" "$BY" ;;
      forge)    printf "%s" "$BM" ;;
      gemini)   printf "%s" "$BB" ;;
      goose)    printf "%s" "$BG" ;;
      muse)     printf "%s" "$MO" ;;
      opencode) printf "%s" "$BW" ;;
      *)          printf "%s" "$D" ;;
    esac
  }

  _opencode_backend_error() {
    printf "\n  %bOpenCode backend could not %s.%b\n" \
      "${BR}${B}✗${X}  ${BW}" "$1" "$X" >&2
    printf "  %bInspect it with: systemctl --user status %s%b\n\n" \
      "$D" "$_opencode_service" "$X" >&2
  }

  _capture_opencode_runtime_path() {
    local -a path_parts=()
    local part candidate="" existing
    IFS=':' read -r -a path_parts <<< "$PATH"
    for part in "${path_parts[@]}"; do
      [[ -n "$part" && "$part" =~ ^[A-Za-z0-9_./+@%=-]+$ ]] || continue
      existing=0
      case ":$candidate:" in
        *":$part:"*) existing=1 ;;
      esac
      [[ $existing -eq 1 ]] && continue
      candidate+="${candidate:+:}$part"
    done
    [[ -n "$candidate" ]] || return 1
    _opencode_runtime_path="$candidate"
  }

  _opencode_service_state() {
    systemctl --user show --property=ActiveState --value \
      "$_opencode_service" 2>/dev/null
  }

  _prepare_opencode_backend() {
    local config_dir="$HOME/.config/crazycode"
    local systemd_dir="$HOME/.config/systemd/user"
    local env_file="$config_dir/opencode.env"
    local lock_file="$config_dir/setup.lock"
    local unit_file="$systemd_dir/$_opencode_service"
    local unit_template="$_crazycode_source_dir/systemd/$_opencode_service"

    if [[ ! -f "$unit_template" ]]; then
      _opencode_backend_error "find its service template"
      return 1
    fi
    if ! command -v flock >/dev/null 2>&1; then
      _opencode_backend_error "acquire its setup lock (flock is missing)"
      return 1
    fi
    if ! _capture_opencode_runtime_path; then
      _opencode_backend_error "capture a safe executable search path"
      return 1
    fi

    install -d -m 700 "$config_dir" || {
      _opencode_backend_error "create its private configuration directory"
      return 1
    }
    install -d -m 700 "$systemd_dir" || {
      _opencode_backend_error "create the user service directory"
      return 1
    }
    (umask 077; : >> "$lock_file") || {
      _opencode_backend_error "create its setup lock"
      return 1
    }
    chmod 600 "$lock_file" || return 1

    if ! (
      flock -x 9

      if [[ -L "$env_file" || -L "$unit_file" ]]; then
        exit 1
      fi

      if ! cmp -s "$unit_template" "$unit_file"; then
        install -m 644 "$unit_template" "$unit_file" || exit 1
        systemctl --user daemon-reload >/dev/null 2>&1 || exit 1
      fi

      local -a secret_lines=()
      local password="" state="" tmp_file=""
      local password_valid=0 file_current=0
      if [[ -f "$env_file" ]]; then
        mapfile -t secret_lines < "$env_file"
        if [[ ${#secret_lines[@]} -ge 1 \
              && "${secret_lines[0]}" =~ ^OPENCODE_SERVER_PASSWORD=[0-9a-f]{64}$ ]]; then
          password="${secret_lines[0]#*=}"
          password_valid=1
        fi
        if [[ ${#secret_lines[@]} -eq 2 \
              && $password_valid -eq 1 \
              && "${secret_lines[1]}" == "PATH=$_opencode_runtime_path" \
              && "$(stat -c '%a' "$env_file")" == "600" \
              && "$(stat -c '%u' "$env_file")" == "$(id -u)" ]]; then
          file_current=1
        fi
      fi

      if [[ $file_current -eq 0 ]]; then
        if [[ $password_valid -eq 0 ]]; then
          state="$(_opencode_service_state)" || exit 1
          case "$state" in
            active|activating) exit 1 ;;
          esac
          password="$(od -An -N32 -tx1 /dev/urandom | tr -d ' \n')"
          [[ "$password" =~ ^[0-9a-f]{64}$ ]] || exit 1
        fi

        tmp_file="$(mktemp "$config_dir/.opencode.env.XXXXXX")" || exit 1
        trap '[[ -z "$tmp_file" ]] || rm -f -- "$tmp_file"' EXIT
        printf 'OPENCODE_SERVER_PASSWORD=%s\nPATH=%s\n' \
          "$password" "$_opencode_runtime_path" > "$tmp_file"
        chmod 600 "$tmp_file" || exit 1
        mv -f -- "$tmp_file" "$env_file" || exit 1
        tmp_file=""
      fi

    ) 9>> "$lock_file"; then
      _opencode_backend_error "provision its private credential and user service"
      return 1
    fi
  }

  _read_opencode_password() {
    local env_file="$HOME/.config/crazycode/opencode.env"
    local -a secret_lines=()
    [[ -f "$env_file" && ! -L "$env_file" ]] || return 1
    mapfile -t secret_lines < "$env_file"
    [[ ${#secret_lines[@]} -eq 2 \
       && "${secret_lines[0]}" =~ ^OPENCODE_SERVER_PASSWORD=[0-9a-f]{64}$ \
       && "${secret_lines[1]}" =~ ^PATH=[A-Za-z0-9_./:+@%=-]+$ \
       && "$(stat -c '%a' "$env_file")" == "600" \
       && "$(stat -c '%u' "$env_file")" == "$(id -u)" ]] || return 1
    _opencode_password="${secret_lines[0]#*=}"
  }

  _monotonic_millis() {
    local uptime whole fraction
    IFS=' ' read -r uptime _ < /proc/uptime || return 1
    [[ "$uptime" =~ ^[0-9]+\.[0-9]+$ ]] || return 1
    whole="${uptime%%.*}"
    fraction="${uptime#*.}000"
    fraction="${fraction:0:3}"
    printf '%s\n' "$((10#$whole * 1000 + 10#$fraction))"
  }

  _ensure_opencode_backend() {
    local config_dir="$HOME/.config/crazycode"
    local lock_file="$config_dir/setup.lock"
    local timeout_seconds="${CRAZYCODE_OPENCODE_READY_TIMEOUT_SECONDS:-45}"
    local started_at deadline now state start_status

    [[ "$timeout_seconds" =~ ^[1-9][0-9]*$ ]] || timeout_seconds=45
    started_at="$(_monotonic_millis)" || {
      _opencode_backend_error "read the monotonic readiness clock"
      return 1
    }
    deadline=$((started_at + timeout_seconds * 1000))

    (
      flock -x 9
      state="$(_opencode_service_state)" || exit 3
      case "$state" in
        active|activating) exit 0 ;;
        failed) exit 2 ;;
        *) systemctl --user start "$_opencode_service" >/dev/null 2>&1 || exit 1 ;;
      esac
    ) 9>> "$lock_file"
    start_status=$?
    case "$start_status" in
      0) ;;
      2)
        _opencode_backend_error "recover from its failed state"
        return 1
        ;;
      *)
        _opencode_backend_error "start"
        return 1
        ;;
    esac

    while true; do
      state="$(_opencode_service_state)" || state="unknown"
      case "$state" in
        active|activating) ;;
        failed)
          _opencode_backend_error "recover from its failed state"
          return 1
          ;;
        *)
          _opencode_backend_error "remain active while becoming ready"
          return 1
          ;;
      esac

      if printf 'user = "opencode:%s"\n' "$_opencode_password" \
          | curl --config - --silent --fail --output /dev/null --max-time 1 \
              "$_opencode_url/global/health"; then
        return 0
      fi

      now="$(_monotonic_millis)" || break
      (( now >= deadline )) && break
      sleep 0.1
    done

    _opencode_backend_error "become ready"
    return 1
  }

  _launch_shared_opencode() {
    _prepare_opencode_backend || return 1
    if ! _read_opencode_password; then
      _opencode_backend_error "read its private credential"
      return 1
    fi
    if ! _ensure_opencode_backend; then
      _opencode_password=""
      return 1
    fi

    local status
    if OPENCODE_SERVER_PASSWORD="$_opencode_password" \
        opencode attach "$_opencode_url" --dir "$PWD" "$@"; then
      status=0
    else
      status=$?
    fi
    _opencode_password=""
    return "$status"
  }

  awake_count() {
    _awake_count=0
    [[ $sleep_masked -eq 1 ]] && ((_awake_count++))
    [[ $idle_inhibited -eq 1 ]] && ((_awake_count++))
    [[ $lid_ignored -eq 1 ]] && ((_awake_count++))
    [[ $lock_disabled -eq 1 ]] && ((_awake_count++))
  }

  get_awake_line() {
    awake_count
    local count=$_awake_count
    if [[ $count -eq 4 ]]; then
      printf "  ${BW}[c]${X} ${D}camomile${X} ${D}🌿${X}       ${BG}[awake mode on]${X}"
    elif [[ $count -gt 0 ]]; then
      printf "  ${BW}[c]${X} ${BG}coffeeshot${X} ${BG}☕${X}     ${BY}[partial ${count}/4]${X}"
    else
      printf "  ${BW}[c]${X} ${BG}coffeeshot${X} ${BG}☕${X}     ${D}[awake mode off]${X}"
    fi
  }

  # _launch_tool <idx> <resume 0|1> [args passed through to the tool...]
  # Both leading arguments are mandatory: a caller that omits `resume` makes the
  # user's first argument bind to it, where `shift 2` then eats it.
  _launch_tool() {
    local idx=$1 resume=$2
    shift 2
    local tool="${items[$idx]}"
    local cmd="${cmds[$idx]}"
    local color
    color=$(get_color "$tool")

    if ! command -v "$cmd" &>/dev/null; then
      printf "\n  ${BR}${B}✗${X}  ${BW}${tool}${X} ${D}is not installed.${X}\n"
      printf "  ${D}Run the installer to set it up:${X}\n"
      printf "  ${D}  curl -fsSL https://raw.githubusercontent.com/Ymx1ZQ/crazycode/main/install.sh | bash${X}\n\n"
      printf "  ${D}press any key to return to menu...${X}"
      read -rsn1
      return 1
    fi

    # Per-tool environment overrides applied immediately before invocation.
    # forge: telemetry defaults to ON and processes events on US infrastructure
    # with no data-processing agreement in place. Opt-out by default; users who
    # want telemetry on can `unset FORGE_TRACKER` in their shell after launch.
    # goose: GOOSE_MODE defaults to smart_approve (interactive confirmations).
    # Override to `auto` to match crazycode's "all tools launch without asking
    # permission" stance — same role as --yes-always/--yolo for the others.
    local env_prefix=""
    if [[ "$tool" == "forge" ]]; then
      env_prefix="FORGE_TRACKER=0"
    elif [[ "$tool" == "goose" ]]; then
      env_prefix="GOOSE_MODE=auto"
    fi

    # String comparison, not `-eq`: `[[ x -eq 1 ]]` evaluates x as an arithmetic
    # expression, and bash performs command substitution while doing so.
    if [[ "$resume" == "1" ]]; then
      printf "\n  ${color}${B}Resuming ${tool}...${X}\n"
      [[ -n "${resume_hints[$idx]}" ]] && printf "  ${D}${resume_hints[$idx]}${X}\n"
      printf "\n"
      # codex reaches its picker through a subcommand; `--last` would skip the
      # picker, and the launch_args carry the no-approval flags that a resumed
      # session needs just as much as a fresh one.
      if [[ "$tool" == "opencode" ]]; then
        _launch_shared_opencode "$@"
      elif [[ "$tool" == "codex" ]]; then
        # shellcheck disable=SC2086
        env $env_prefix ${cmd} resume ${launch_args[$idx]} "$@"
      elif [[ "$tool" == "muse" ]]; then
        # shellcheck disable=SC2086
        env $env_prefix ${cmd} ${launch_args[$idx]} resume "$@"
      else
        # shellcheck disable=SC2086
        env $env_prefix ${cmd} ${launch_args[$idx]} ${resume_args[$idx]} "$@"
      fi
    else
      printf "\n  ${color}${B}Launching ${tool}...${X}\n\n"
      if [[ "$tool" == "opencode" ]]; then
        _launch_shared_opencode "$@"
      else
        # shellcheck disable=SC2086
        env $env_prefix ${cmd} ${launch_args[$idx]} "$@"
      fi
    fi
  }

  _print_status() {
    check_awake
    local on="${BG}✓${X}" off="${BR}✗${X}"
    printf "\n  ${BW}${B}awake mode status${X}\n"
    printf "  ───────────────────────────\n"
    printf "  sleep masked:    %b\n" "$( [[ $sleep_masked -eq 1 ]] && echo "$on" || echo "$off" )"
    printf "  idle inhibitor:  %b\n" "$( [[ $idle_inhibited -eq 1 ]] && echo "$on" || echo "$off" )"
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
    printf "    ${BR}aider${X}      Launch aider (--yes-always)\n"
    printf "    ${BC}claude${X}     Launch Claude Code (--dangerously-skip-permissions)\n"
    printf "    ${BY}codex${X}      Launch codex (--sandbox danger-full-access)\n"
    printf "    ${BM}forge${X}      Launch ForgeCode (FORGE_TRACKER=0 set by default)\n"
    printf "    ${BB}gemini${X}     Launch Gemini CLI (--yolo)\n"
    printf "    ${BG}goose${X}      Launch Goose (GOOSE_MODE=auto set by default)\n"
    printf "    ${MO}muse${X}       Launch Muse Code (Meta) (--yolo)\n"
    printf "    ${BW}opencode${X}   Attach to shared OpenCode backend\n"
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
      # `0` is the resume flag; everything after it belongs to the tool.
      # Resuming from the CLI needs no subcommand of its own — the tool's own
      # flag forwards straight through (`crazycode claude --resume`).
      _launch_tool "$idx" 0 "$@"
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

  # header = blank + title + path + [git] + separator
  local hdr=4
  git rev-parse --is-inside-work-tree &>/dev/null && hdr=5
  local _last_session=""

  # cache install status (doesn't change during session)
  local -a installed=()
  local i
  for i in "${!cmds[@]}"; do
    command -v "${cmds[$i]}" &>/dev/null && installed+=("${BG}✓${X}") || installed+=("${BR}✗${X}")
  done

  draw_line() {
    local idx=$1 is_selected=$2
    local item="${items[$idx]}"
    local color
    color=$(get_color "$item")

    local num=$((idx + 1))
    local row=$((hdr + 1 + idx))
    echo -ne "\033[${row};1H\033[K"
    if [ "$is_selected" -eq 1 ]; then
      printf "  ${BW}${B}▶${X} ${B}${color}%-15s${X} ${D}%s${X}  %b" "$item" "${descriptions[$idx]}" "${installed[$idx]}"
    else
      printf "  ${D}${num}${X} ${color}%-15s${X} ${D}%s${X}  %b" "$item" "${descriptions[$idx]}" "${installed[$idx]}"
    fi
  }

  draw_awake() {
    local row=$((hdr + num_items + 2))
    echo -ne "\033[${row};1H\033[K"
    get_awake_line
  }

  draw_all() {
    check_awake
    clear
    printf "\n"
    printf "  ${BR}${B}⚡  CRAZYCODE${X}          ${BW}📂 ${PWD##*/}${X}\n"
    printf "  ${D}%s${X}\n" "$PWD"
    if [[ $hdr -eq 5 ]]; then
      local branch dirty=""
      branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
      [[ -n $(git status --porcelain 2>/dev/null) ]] && dirty=" ${BY}●${X}"
      printf "  ${D}⎇${X}  ${BW}${branch}${X}%b\n" "$dirty"
    fi
    printf "  ${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${X}\n"
    local i
    for i in "${!items[@]}"; do draw_line "$i" 0; done
    # Everything below positions its own row, so none of it ends with "\n".
    # The newline would be one row more than the layout occupies, and on a
    # terminal exactly as tall as the layout that scrolls the menu up one row
    # while the draws that follow keep addressing the old rows.
    printf "\033[$((hdr + num_items + 1));1H  ${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${X}"
    draw_awake
    printf "\033[$((hdr + num_items + 3));1H  ${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${X}"
    local help_line="${B}↑↓/1-8${X}${D} select  ·  ${X}${B}enter${X}${D} launch  ·  ${X}${B}r${X}${D} resume"
    help_line+="  ·  ${X}${B}c${X}${D} toggle awake mode  ·  ${X}${B}q${X}${D} quit${X}"
    printf "\033[$((hdr + num_items + 4));1H  ${D}${help_line}"
    local footer_row=$((hdr + num_items + 5))
    if [[ -n "$_last_session" ]]; then
      printf "\033[${footer_row};1H  ${D}⏱  last session: ${items[$_last_tool]} · ${_last_session}${X}"
      ((footer_row++))
    fi
    printf "\033[${footer_row};1H  ${BY}⚠${X}  ${D}all tools launch without asking permission${X}"
    draw_line "$selected" 1
  }

  draw_all
  trap 'draw_all' WINCH

  # ── main TUI loop ────────────────────────────────────────────────
  while true; do

    # ── input loop ──────────────────────────────────────────────────
    local _resume=0
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
          # sudo asks for the password below the footer, and what it prints
          # there is not one line in general: a first-use lecture, a
          # "Sorry, try again." per wrong password, the newline the user's Enter
          # echoes on the bottom row. Any of those scrolls the screen, and every
          # draw here addresses rows absolutely from the top — an assumption
          # only `clear` restores. So repaint the whole screen instead of
          # patching the awake line in place; draw_all ends on the selected
          # entry, which is also where the cursor belongs.
          local _extra=0
          [[ -n "$_last_session" ]] && _extra=1
          local prompt_row=$((hdr + num_items + 6 + _extra))
          echo -ne "\033[${prompt_row};1H\033[K"
          sudo -v
          if is_awake; then
            disable_awake
          else
            enable_awake
          fi
          draw_all
          ;;
        [rR])
          # Resume mode for whatever is highlighted, available from the first
          # keystroke — no tool needs to have run in this crazycode session
          # first, and the selection is never overwritten.
          _resume=1
          break
          ;;
        [1-8])
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

    # ── launch selected tool ────────────────────────────────────────
    clear
    local _t0=$SECONDS
    _launch_tool "$selected" "$_resume" "$@"
    _last_tool=$selected
    stty sane 2>/dev/null
    # Drain stray input the child TUI left behind. Terminal query responses
    # (cursor-position / device-attributes reports) arrive after the child has
    # exited; without this the menu's read loop consumes them as keystrokes —
    # a stray digit launches whatever tool maps to it (e.g. opencode → codex).
    local _drain
    while read -rsn1 -t 0.05 _drain; do :; done
    local _elapsed=$(( SECONDS - _t0 ))
    local _m=$(( _elapsed / 60 )) _s=$(( _elapsed % 60 ))
    if [[ $_m -gt 0 ]]; then
      _last_session="${_m}m ${_s}s"
    else
      _last_session="${_s}s"
    fi
    draw_all

  done
}

# ── bash completion ──────────────────────────────────────────────────
_crazycode_completions() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  COMPREPLY=( $(compgen -W "aider claude codex forge gemini goose muse opencode coffeeshot status --help" -- "$cur") )
}
# NOTE: completion words match items array + extra commands; update if items change
complete -F _crazycode_completions crazycode

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  _crazycode_main "$@"
fi
