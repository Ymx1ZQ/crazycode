#!/usr/bin/env bash

crazycode() {
  local R='\033[0;31m' Y='\033[0;33m' C='\033[0;36m' W='\033[0;37m' D='\033[2;37m' G='\033[0;32m' X='\033[0m'

  # Check initial states
  local caffeine_on=0 sleep_masked=0
  pgrep -f caffeine-indicator >/dev/null 2>&1 && caffeine_on=1
  systemctl is-enabled sleep.target 2>/dev/null | grep -q masked && sleep_masked=1

  while true; do
    local caffeine_label sleep_label
    if [ "$caffeine_on" -eq 1 ]; then
      caffeine_label="${G}☕ active${X}"
    else
      caffeine_label="${D}off${X}"
    fi
    if [ "$sleep_masked" -eq 1 ]; then
      sleep_label="${Y}🚫 on${X}"
    else
      sleep_label="${D}off${X}"
    fi

    echo
    echo -e "  ${R}⚡ CRAZYCODE${X}"
    echo -e "  ${D}─────────────────────────────${X}"
    echo -e "  ${W}[a]${X} ${R}aider${X}          ${D}(aider-ai)${X}"
    echo -e "  ${W}[c]${X} ${C}claudecode${X}     ${D}(anthropic)${X}"
    echo -e "  ${W}[o]${X} ${W}opencode${X}       ${D}(sst)${X}"
    echo -e "  ${W}[x]${X} ${Y}codex${X}          ${D}(openai)${X}"
    echo -e "  ${D}─────────────────────────────${X}"
    echo -e "  ${W}[s]${X} coffeeshot     ${D}(screen awake)${X}   [${caffeine_label}${X}]"
    echo -e "  ${W}[l]${X} nosleep        ${D}(block suspend)${X}  [${sleep_label}${X}]"
    echo -e "  ${D}─────────────────────────────${X}"
    echo -e "  ${W}[q]${X} ${D}quit${X}"
    echo
    local choice
    read -rn1 -p "  $(echo -e "${D}> ${X}")" choice
    echo

    case "$choice" in
      a)
        echo -e "  ${R}Launching aider...${X}\n"
        aider --yes-always "$@"
        pgrep -f caffeine-indicator >/dev/null 2>&1 && caffeine_on=1 || caffeine_on=0
        systemctl is-enabled sleep.target 2>/dev/null | grep -q masked && sleep_masked=1 || sleep_masked=0
        ;;
      c)
        echo -e "  ${C}Launching claudecode...${X}\n"
        claude --dangerously-skip-permissions "$@"
        pgrep -f caffeine-indicator >/dev/null 2>&1 && caffeine_on=1 || caffeine_on=0
        systemctl is-enabled sleep.target 2>/dev/null | grep -q masked && sleep_masked=1 || sleep_masked=0
        ;;
      o)
        echo -e "  ${W}Launching opencode...${X}\n"
        opencode "$@"
        pgrep -f caffeine-indicator >/dev/null 2>&1 && caffeine_on=1 || caffeine_on=0
        systemctl is-enabled sleep.target 2>/dev/null | grep -q masked && sleep_masked=1 || sleep_masked=0
        ;;
      x)
        echo -e "  ${Y}Launching codex...${X}\n"
        codex --sandbox danger-full-access --ask-for-approval never "$@"
        pgrep -f caffeine-indicator >/dev/null 2>&1 && caffeine_on=1 || caffeine_on=0
        systemctl is-enabled sleep.target 2>/dev/null | grep -q masked && sleep_masked=1 || sleep_masked=0
        ;;
      s)
        if [ "$caffeine_on" -eq 1 ]; then
          # Turn off: kill caffeine-indicator
          pkill -f caffeine-indicator 2>/dev/null
          echo "Coffeeshot off — screen sleep restored."
          caffeine_on=0
        else
          # Turn on: launch caffeine-indicator and activate via DBus
          if ! dpkg -s caffeine >/dev/null 2>&1; then
            echo "Installing caffeine..."
            sudo apt install -y caffeine
          fi
          caffeine-indicator >/dev/null 2>&1 &
          disown
          sleep 2
          local bus
          bus=$(gdbus call --session \
            --dest org.kde.StatusNotifierWatcher \
            --object-path /StatusNotifierWatcher \
            --method org.freedesktop.DBus.Properties.Get \
            org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems 2>/dev/null \
            | grep -oP ":[^']+(?=@[^']*caffeine)")
          if [ -n "$bus" ]; then
            gdbus call --session --dest "$bus" \
              --object-path /org/ayatana/NotificationItem/caffeine_cup_empty \
              --method org.kde.StatusNotifierItem.XAyatanaSecondaryActivate 0 \
              >/dev/null 2>&1
            echo "☕ Coffeeshot active — screen stays on!"
          else
            echo "Error: caffeine indicator not found on DBus"
          fi
          caffeine_on=1
        fi
        ;;
      l)
        if [ "$sleep_masked" -eq 1 ]; then
          # Turn off: restore sleep
          sudo systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target
          sleep_masked=0
        else
          # Turn on: block sleep/suspend
          sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
          sleep_masked=1
        fi
        ;;
      q|'') return ;;
      *) echo -e "  ${D}Unknown: '$choice'${X}" ;;
    esac
  done
}
