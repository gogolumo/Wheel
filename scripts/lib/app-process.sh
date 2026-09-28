#!/usr/bin/env bash

# Match a Wheel process by the exact executable path that owns it. Process
# names are not identities: an unrelated binary may also be named "Wheel".

wheel_process_matches_executable() {
    if [[ $# -ne 2 || ! "$1" =~ ^[0-9]+$ || -z "$2" ]]; then
        return 2
    fi

    local pid="$1"
    local expected_executable="$2"
    local command_line
    command_line="$(ps -ww -p "$pid" -o command= 2>/dev/null)" || return 1
    command_line="${command_line#"${command_line%%[![:space:]]*}"}"

    case "$command_line" in
        "$expected_executable"|"$expected_executable "*) return 0 ;;
    esac
    return 1
}

wheel_find_running_pid() {
    if [[ $# -ne 1 || -z "$1" ]]; then
        return 2
    fi

    local expected_executable="$1"
    local pid
    while IFS= read -r pid; do
        [[ -n "$pid" ]] || continue
        if wheel_process_matches_executable "$pid" "$expected_executable"; then
            printf '%s\n' "$pid"
            return 0
        fi
    done < <(pgrep -x Wheel 2>/dev/null || true)

    return 1
}
