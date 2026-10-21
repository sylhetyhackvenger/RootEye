#!/data/data/com.termux/files/usr/bin/bash

R='\033[0;31m'  G='\033[0;32m'  Y='\033[1;33m'
B='\033[0;34m'  C='\033[0;36m'  M='\033[0;35m'
W='\033[1;37m'  DIM='\033[2m'   BOLD='\033[1m'
LG='\033[1;92m'
RST='\033[0m'

UI_DUMP="/sdcard/ui_dump.xml"
SHOW_UI=true
SHOW_NET=true

sec() { echo -e "\n${BOLD}${Y}▌ $1${RST}"; printf "${Y}%0.s─${RST}" {1..62}; echo; }
info(){ echo -e "  ${G}➜${RST} $*"; }
dim() { echo -e "  ${DIM}$*${RST}"; }

setup_deps() {
    echo -e "${C}[SETUP] Installing packages...${RST}"
    pkg update -y
    pkg install -y tsu procps iproute2 net-tools 2>/dev/null
    echo -e "${G}[SETUP] Done. Run without --setup now.${RST}"
    exit 0
}

check_root() {
    if ! su -c "id" 2>/dev/null | grep -q "uid=0"; then
        echo -e "${R}[ERROR] Root required. Grant root to Termux.${RST}"
        exit 1
    fi
    echo -e "${G}[✓] Root confirmed${RST}"
}

get_fg_app() {
    su -c "dumpsys activity activities 2>/dev/null" \
        | grep -E "mResumedActivity|ResumedActivity" \
        | head -1 \
        | sed -E 's/.*ActivityRecord\{[^ ]+ [^ ]+ ([^/]+)\/.*/\1/'
}

get_fg_activity() {
    su -c "dumpsys activity activities 2>/dev/null" \
        | grep -E "mResumedActivity|ResumedActivity" \
        | head -1 \
        | sed -E 's/.*ActivityRecord\{[^ ]+ [^ ]+ ([^ ]+) .*/\1/'
}

get_window_focus() {
    su -c "dumpsys window 2>/dev/null" \
        | grep -E "mCurrentFocus|mFocusedApp" \
        | sed 's/^[[:space:]]*//'
}

get_stack_history() {
    su -c "dumpsys activity recents 2>/dev/null" \
        | grep "baseActivity=" \
        | sed -E 's/.*baseActivity=ComponentInfo\{([^/]+)\/.*/\1/' \
        | head -8
}

dump_ui() {
    su shell -c "uiautomator dump --compressed $UI_DUMP 2>/dev/null" 2>/dev/null \
    || su -c "uiautomator dump --compressed $UI_DUMP 2>/dev/null" 2>/dev/null
}

parse_ui() {
    local xml
    xml=$(su -c "cat $UI_DUMP 2>/dev/null")
    su -c "rm -f $UI_DUMP 2>/dev/null"
    [ -z "$xml" ] && dim "(no UI data — app may block accessibility)" && return

    local texts descs clickables inputs scrolls

    texts=$(echo "$xml"      | grep -oP 'text="[^"]+"'         | sed 's/text="//;s/"$//'         | grep -v '^$' | sort -u)
    descs=$(echo "$xml"      | grep -oP 'content-desc="[^"]+"' | sed 's/content-desc="//;s/"$//' | grep -v '^$' | sort -u)
    clickables=$(echo "$xml" | grep -oP '<node[^>]*clickable="true"[^>]*/>' \
                             | grep -oP 'text="[^"]+"' | sed 's/text="//;s/"$//' | grep -v '^$' | sort -u)
    inputs=$(echo "$xml"     | grep -oP '<node[^>]*class="android\.widget\.EditText"[^>]*/>' \
                             | grep -oP '(text|hint|content-desc)="[^"]+"' \
                             | sed -E 's/(text|hint|content-desc)="(.*)"/[\1] \2/' | grep -v '\[\] $' | sort -u)
    scrolls=$(echo "$xml"    | grep -oP '<node[^>]*scrollable="true"[^>]*/>' \
                             | grep -oP 'class="[^"]+"' | sed 's/class="//;s/"$//' | sort -u)

    if [ -n "$texts" ]; then
        echo -e "  ${G}Text on screen:${RST}"
        echo "$texts" | head -30 | while IFS= read -r t; do echo -e "    ${W}· $t${RST}"; done
    fi

    if [ -n "$descs" ]; then
        echo -e "\n  ${B}Accessibility labels:${RST}"
        echo "$descs" | head -15 | while IFS= read -r d; do echo -e "    ${C}· $d${RST}"; done
    fi

    if [ -n "$clickables" ]; then
        echo -e "\n  ${M}Clickable buttons / links:${RST}"
        echo "$clickables" | head -15 | while IFS= read -r c; do echo -e "    ${M}· $c${RST}"; done
    fi

    if [ -n "$inputs" ]; then
        echo -e "\n  ${R}Input fields:${RST}"
        echo "$inputs" | while IFS= read -r i; do echo -e "    ${R}· $i${RST}"; done
    fi

    if [ -n "$scrolls" ]; then
        echo -e "\n  ${DIM}Scrollable views: $scrolls${RST}"
    fi
}

get_notifications() {
    su -c "dumpsys notification 2>/dev/null" \
        | grep -E "pkg=|NotificationRecord|text=|tickerText|title=" \
        | grep -v "^$" | head -20
}

get_clipboard() {
    su -c "dumpsys clipboard 2>/dev/null" | grep -i "text\|clip" | head -5
}

get_logcat_snap() {
    su -c "logcat -d -v time -s ActivityManager:I ActivityTaskManager:I WindowManager:I *:S 2>/dev/null" \
        | tail -12
}

get_network() {
    echo -e "  ${G}TCP connections:${RST}"
    su -c "ss -tnp 2>/dev/null" | grep -v "^State" | head -12 \
        | while IFS= read -r line; do echo -e "    ${C}$line${RST}"; done

    echo -e "\n  ${G}Network interfaces:${RST}"
    su -c "ip -o addr show 2>/dev/null" \
        | awk '{print "    "$2"  "$4}' \
        | while IFS= read -r line; do echo -e "${W}$line${RST}"; done
}

get_system() {
    echo -e "  ${G}Battery:${RST}"
    su -c "dumpsys battery 2>/dev/null" \
        | grep -E "level:|status:|temperature:|plugged:" \
        | sed 's/^[[:space:]]*//' \
        | while IFS= read -r line; do echo -e "    ${W}$line${RST}"; done

    echo -e "\n  ${G}Top CPU processes:${RST}"
    su -c "top -b -n 1 2>/dev/null" \
        | grep -v "^$\|PID\|Mem\|Swap\|Tasks\|Cpu\|KiB" \
        | head -8 \
        | awk '{printf "    %-8s %-6s %-6s %s\n", $1,$9,$10,$NF}' \
        | while IFS= read -r line; do echo -e "${DIM}$line${RST}"; done

    echo -e "\n  ${G}Memory:${RST}"
    su -c "cat /proc/meminfo 2>/dev/null" \
        | grep -E "MemTotal|MemFree|MemAvailable|Buffers:|Cached:" \
        | while IFS= read -r line; do echo -e "    ${W}$line${RST}"; done
}

APP_HISTORY=()

record_app() {
    local app="$1"
    local ts
    ts=$(date '+%H:%M:%S')
    [ "${APP_HISTORY[-1]}" != "$app" ] && APP_HISTORY+=("$ts  $app")
}

show_app_history() {
    local count=${#APP_HISTORY[@]}
    local start=$(( count > 8 ? count - 8 : 0 ))
    for (( i=start; i<count; i++ )); do
        echo -e "    ${M}${APP_HISTORY[$i]}${RST}"
    done
}

print_banner() {
    echo -e "${LG}"
    echo "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣠⣴⣾⣿⣿⣿⣿⡿⠿⠛⠋⠁"
    echo "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⡀⠀⠀⢀⣼⣿⣿⣿⣿⠟⠛⠉⠀⠀⠀⠀⠀⠀"
    echo "⠀⠀⠀⠀⣀⣤⣶⣶⣶⣶⣶⣶⣶⣧⣀⠀⠀⠀⢿⣶⣿⣇⣀⣴⣾⣿⣿⣿⡟⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀"
    echo "⢀⣠⣴⠿⠿⠿⠿⠿⠿⣿⣿⣿⣿⣿⣿⣿⣶⣶⣿⣿⣿⣿⣿⣿⡿⠋⠉⠉⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
    echo "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠻⣿⠿⠛⠛⢿⡿⠿⢿⣿⣿⠋⠉⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
    echo "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠁⠀⠈⠙⡁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
    echo -e "${RST}"
}

print_header() {
    clear
    print_banner
    echo -e "${BOLD}${C}"
    echo "  ╔══════════════════════════════════════════════════════════╗"
    echo "  ║        📱  ROOTEYE — VIEW ELEMENT eXTRACTOR  📱          ║"
    echo "  ║   No files saved · No logs · Terminal only · Root       ║"
    echo "  ╚══════════════════════════════════════════════════════════╝${RST}"
    echo -e "  ${W}$(date '+%A, %d %B %Y  %H:%M:%S')${RST}"
    echo -e "  ${DIM}  by SYLHETYHACKVENGER (THE-ERROR808)${RST}"
}

cleanup() {
    echo -e "\n\n${Y}[!] Monitor stopped. Nothing was saved.${RST}"
    su -c "rm -f $UI_DUMP 2>/dev/null"
    exit 0
}
trap cleanup INT TERM

main() {
    [ "$1" = "--setup" ] && setup_deps

    print_header
    check_root
    sleep 0.4

    echo -e "${G}[✓] Ready — switch to any app, come back, press Enter to read${RST}"
    echo ""
    echo -ne "  ${BOLD}${C}[ Press ENTER to begin ]${RST}  "
    read -r _

    while true; do
        print_header

        sec "FOREGROUND APP"
        local pkg act
        pkg=$(get_fg_app)
        act=$(get_fg_activity)
        record_app "$pkg"
        info "Package : ${W}$pkg${RST}"
        info "Activity: ${C}$act${RST}"
        echo -e "\n  ${G}Window focus:${RST}"
        get_window_focus | while IFS= read -r l; do echo -e "    ${DIM}$l${RST}"; done

        sec "APP HISTORY  (this session only — vanishes on exit)"
        echo -e "  ${G}Recent task stack (Android):${RST}"
        get_stack_history | nl -ba | while IFS= read -r l; do echo -e "    ${C}$l${RST}"; done
        echo -e "\n  ${G}Switches seen this session:${RST}"
        show_app_history

        if $SHOW_UI; then
            sec "UI ELEMENTS — WHAT'S ON SCREEN RIGHT NOW"
            dim "Reading layout hierarchy..."
            dump_ui
            parse_ui
        fi

        sec "ACTIVE NOTIFICATIONS"
        get_notifications | while IFS= read -r l; do echo -e "  ${Y}$l${RST}"; done

        sec "CLIPBOARD"
        local clip
        clip=$(get_clipboard)
        [ -n "$clip" ] && echo -e "  ${R}$clip${RST}" || dim "(empty or inaccessible)"

        if $SHOW_NET; then
            sec "NETWORK ACTIVITY"
            get_network
        fi

        sec "SYSTEM — BATTERY · CPU · MEMORY"
        get_system

        sec "SYSTEM EVENTS (logcat snapshot)"
        get_logcat_snap | while IFS= read -r l; do echo -e "  ${DIM}$l${RST}"; done

        echo ""
        echo -e "${DIM}  ──────────────────────────────────────────────────────────${RST}"
        echo -e "  ${DIM}Nothing saved. All data above lives only in this terminal.${RST}"
        echo ""
        echo -ne "  ${BOLD}${C}[ Press ENTER to scan again  |  Ctrl+C to exit ]${RST}  "
        read -r _
    done
}

main "$@"
