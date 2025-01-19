# UI Colors
PAUSE_BUTTON_COLOR="f7ce46ff" # Top left of battle screen
PAUSE_BUTTON_COORDS="245 30"

START_BATTLE_BUTTON_COORDS="2307 1020"
START_BATTLE_BUTTON_COLOR="e0b13cff"

UNPAUSE_BUTTON_COORDS="2000 350"

# network failure red text for energy recovery
RED_TEXT_COORDS="2148 788"
RED_TEXT_COLOR="ea3424ff"
WHITE_TEXT_COLOR="ffffffff"

# The Android dialog opens when restarting while in a stage
# should be white color
RESET_STATE_DIALOG_COORDS="1630 730"

# Return to map when a stage ends
RETURN_TO_MAP_COORDS="2865 120"
LEVEL_UPGRADE_COORDS="300 1330"

# The dialog opens when starting a stage without enough energy
STAGE_BEGIN_NO_ENERGY_COORDS="1987 930"

# Cat deploy row settings
CAT_DEPLOY_X_OFFSET=950
CAT_DEPLOY_Y_OFFSET=1115

CAT_DEPLOY_X_SPACING=300
CAT_DEPLOY_Y_SPACING=200

# Open ticket storage button
TICKET_STORAGE="560 1200"
TICKET_DRAW_10="2450 1200"

# Two buttons on the main storage interface
TICKET_STORAGE_USE="1325 1386"
# Exchange to XP/NP button
TICKET_STORAGE_EXCHANGE="1900 1385"
# Exchange to rare ticket button
TICKET_STORAGE_EXCHANGE_RARE="2230 870"
# Confirm exchange
TICKET_STORAGE_EXCHANGE_RARE_YES="1260 1170"

# Exchange to NP button
TICKET_STORAGE_EXCHANGE_NP="1234 874"
TICKET_STORAGE_EXCHANGE_XP="1800 874"
# Confirm exchange
TICKET_STORAGE_EXCHANGE_NP_YES="1234 874"

# Close the "storage is full!" dialog
TICKET_STORAGE_FULL_OK="2070 950"
TICKET_STORAGE_BACK="270 1300"

# Number of seconds to wait for screen switch
SWITCH_SCREEN_DELAY=0.5

# Number of minutes to reset state
RESET_STATE_INTERVAL=90

# Reference: https://android.googlesource.com/platform/frameworks/base/+/e639da7/core/java/android/app/AlarmManager.java
# Set datetime: service call alarm 2 i64 1661203400000
# Set timezone: service call alarm 3 s16 GMT+13
# Set auto date: settings put global auto_time 1
# 2 days = 172800 seconds

set_zone() {
    local zone="$(printf '%+d' "$1")"
    if [ "$?" == 0 ] && [ "$zone" -le 14 ] && [ "$zone" -ge "-12" ]; then
        echo "Set timezone to GMT$zone"
        settings put global auto_time_zone 0
        service call alarm 3 s16 "GMT$zone" >/dev/null
    else
        settings put global auto_time_zone 1
    fi
}

set_time() {
    local timediff="$(printf '%d' "$1")"
    if [ "$?" == 0 ] && [ "$timediff" -ne 0 ]; then
        settings put global auto_time 0
        ((target_time = "$(date +%s)" + timediff))
        log "Set time to $target_time"
        service call alarm 2 i64 "${target_time}000" >/dev/null
    else
        settings put global auto_time 1
    fi
}

getcolor() {
    w="${4:-3120}"
    h="${5:-1440}"
    x="$1"
    y="$2"
    len="${3:-1}"

    offset="$(((y * w + x + 4) * 4))"
    screencap | head -c "$((offset + len * 4))" | tail -c "$((len * 4))" | xxd -p

    #screencap | dd bs=4 count="$len" skip="$offset" 2>/dev/null | xxd -p | tr -d ' \n'
}

getcolor2() {
    getcolor "$1" "$2" "$3" 1440 3120
}

go() {
    am start -W --activity-single-top --activity-no-animation "$@" >/dev/null
}

gonow() {
    am start --activity-single-top --activity-no-animation "$@" >/dev/null
}

go_settings() {
    go -n 'com.android.settings/.Settings$DateTimeSettingsActivity'
    [ -n "$1" ] && sleep "$1"
}

go_cats() {
    go -n 'jp.co.ponos.battlecats/.MyActivity'
    [ -n "$1" ] && sleep "$1"
}

gonow_cats() {
    gonow -n 'jp.co.ponos.battlecats/.MyActivity'
    [ -n "$1" ] && sleep "$1"
}

go_home() {
    go -a 'android.intent.action.MAIN' -c 'android.intent.category.HOME'
    [ -n "$1" ] && sleep "$1"
}

go_play() {
    go -n 'com.android.vending/com.google.android.finsky.activities.MainActivity'
    [ -n "$1" ] && sleep "$1"
}

gonow_play() {
    gonow -n 'com.android.vending/com.google.android.finsky.activities.MainActivity'
    [ -n "$1" ] && sleep "$1"
}

tap() {
    input tap "$1" "$2"
    [ -n "$3" ] && sleep "$3"
}

hold() {
    input swipe "$1" "$2" "$1" "$2" "$3"
    [ -n "$4" ] && sleep "$4"
}

key() {
    input keyevent "$1"
    [ -n "$2" ] && sleep "$2"
}

help() {
    echo $@
    echo "$0 [-c | --count <repeat>] [-d | --deploy <deploy_pattern>] [-z | --fix-timezone] [-zs | --strict-timezone]"
    echo "        [-n | --limit <clear_limit>]"
    exit 0
}

log() {
    s="$1"
    shift
    printf "%s $s\n" "$(date +'[%F %T]')" $@
}

run_stage() {
    deploy_pattern="$1"

    while true; do
        # Deploy cats loop
        for i in $deploy_pattern; do
            # Check if stage ended, termination condition
            k=1
            while ((k <= 5)); do
                if [ "$(getcolor $PAUSE_BUTTON_COORDS)" == "$PAUSE_BUTTON_COLOR" ]; then
                    ((k > 1)) && log "k=$k"
                    break
                fi

                # if dumpsys activity activities | grep Hist -m 1 | grep -v jp.co.ponos.battlecats/.MyActivity; then
                #     sleep 3
                #     k=1
                #     continue
                # fi

                hold $UNPAUSE_BUTTON_COORDS 100 0.4
                ((k++ >= 5)) && return 0
            done

            if [ "$i" = "u" ]; then
                # log "upgrade"
                hold $LEVEL_UPGRADE_COORDS 100 0.1
                continue
            fi

            ((row = (i - 1) / 5))
            ((idx = (i - 1) % 5))

            # Click to deploy unit
            ((cat_x = idx * CAT_DEPLOY_X_SPACING + CAT_DEPLOY_X_OFFSET))
            ((cat_y = row * CAT_DEPLOY_Y_SPACING + CAT_DEPLOY_Y_OFFSET))

            (input tap "$cat_x" "$cat_y" &)
            sleep 0.2
        done
    done
}

fix_time() {
    log 'Trying to fix time...'

    go_home 0.2

    set_time # set auto time

    go_cats 0.2
}

reset_time() {
    local next_zone hour zone

    if [ -n "$fix_timezone" ]; then
        # Figure out the timezone
        read -r hour zone <<<"$(date +'%H %z')"

        if ((hour != start_hour)); then
            ((next_zone = zone / 100 - 1))

            if ((next_zone < -12)); then
                log "Cannot fix timezone anymore, giving up."
                unset fix_timezone next_zone
            fi
        fi
    fi

    go_play
    set_time -172800 # -2 days

    if [ -n "$next_zone" ]; then
        log "Change timezone to $next_zone"
        set_zone "$next_zone"
    fi
    go_cats 0.5

    # go_play
    set_time # Set auto time on
    go_cats
}

# Reset the application state by closing all background applications
reset_state() {
    am force-stop 'jp.co.ponos.battlecats' >/dev/null
    am force-stop 'com.android.settings' >/dev/null

    go_settings 0.5

    go_cats 5

    # right, right, enter
    while [ "$(getcolor $RESET_STATE_DIALOG_COORDS)" != "ffffffff" ]; do
        sleep 1
    done

    key 22 0.2
    key 22 0.2
    key 66 0.2 # Enter
}

click_ticket() {
    ticket_type="$1"
    draw_count=0

    log "Ticket Type = $ticket_type"

    if [ "$ticket_type" = "rare" ]; then
        click_rare_ticket
        return 0
    fi

    #     if [ "$ticket_type" != "silver" ]; then
    #         log "invalid ticket type!"
    #         return 1
    #     fi

    # Click silver / event ticket
    while true; do
        i=0
        j=0

        while true; do
            if ((i++ % 10 == 0)); then
                if [ "$(getcolor $TICKET_STORAGE_FULL_OK)" == "ffffffff" ]; then
                    log "j=$j"
                    ((j++ >= 2)) && break
                else
                    ((j = 0))
                fi
            fi
            input tap $TICKET_DRAW_10 0.05
        done

        # log "Tap draw"
        # hold 2260 830 200 0.4

        log "Storage full?"

        tap $TICKET_STORAGE_FULL_OK 0.5
        hold $TICKET_STORAGE 200 1.5

        if [ "$ticket_type" = "silver" ]; then
            hold $TICKET_STORAGE_USE 200 0.5
            hold $TICKET_STORAGE_EXCHANGE_RARE 200 0.5
            hold $TICKET_STORAGE_EXCHANGE_RARE_YES 200 1.5
            hold $TICKET_STORAGE_EXCHANGE_RARE_YES 200 0.5
        fi

        hold $TICKET_STORAGE_EXCHANGE 200 0.5
        # hold $TICKET_STORAGE_EXCHANGE_NP 200 0.5
        hold $TICKET_STORAGE_EXCHANGE_XP 200 0.5
        hold $TICKET_STORAGE_EXCHANGE_NP_YES 200 0.5
        hold $TICKET_STORAGE_BACK 200 1.5
    done
}

click_rare_ticket() {
    while true; do
        input tap 1614 750
        input tap 1637 873
    done
}

main() {
    while [ "$#" -gt 0 ]; do
        key="$1"

        case "$key" in
        -c | --count)
            shift
            repeat="$1"
            shift
            ;;

        -d | --deploy)
            shift
            deploy_pattern=""
            while [ "$1" -gt "0" ]; do
                deploy_pattern+="$1 "
                shift
            done
            ;;

        -n | --limit)
            clear_limit="$2"
            shift
            shift
            ;;

        -z | -f | --fix-timezone)
            fix_timezone="yes"
            shift
            ;;

        -s | -zs | --strict-timezone)
            fix_timezone="strict"
            shift
            ;;

        -r | --reset-time)
            reset_time
            return 0
            ;;

        -h | --help)
            help
            ;;

        *)
            shift
            ;;
        esac
    done

    # Display help
    if [ -z "$repeat" ] || [ -z "$deploy_pattern" ]; then
        help "Missing arguments."
    fi

    clear_count=0
    average=120

    start_hour="$(date +%H)"
    start_zone="$(date +%z)"

    reset_state_count=0

    log "===  Battle Cats  ==="
    log "Repeat = $repeat, limit = $clear_limit, timezone = $fix_timezone"
    log "Deploy pattern: $deploy_pattern"

    if [ -n "$fix_timezone" ]; then
        log "Fix hour: $start_hour, current zone: $start_zone"
    fi

    # Open the app if not in the foreground
    go_cats

    while true; do
        for round in $(seq 1 "$repeat"); do

            current_hour="$(date +%H)"

            # Make sure timezone is correct before clicking the start button.
            # Although rare, it's still possible to fail due to the delay in clicking the button.
            if [ "$fix_timezone" = "strict" ] && ((current_hour != start_hour)); then
                log "Incorrect timezone, cannot begin the stage!"
                stage_begin_energy_failure="yes"
                break
            fi

            # Start battle
            log "Start (#$round)"
            hold $START_BATTLE_BUTTON_COORDS 300 1
            hold $START_BATTLE_BUTTON_COORDS 300 1
            hold $START_BATTLE_BUTTON_COORDS 300 1

            stage_begin="$SECONDS"
            stage_begin_failure="yes"

            # Energy is not successfully recovered
            if [ "$(getcolor $STAGE_BEGIN_NO_ENERGY_COORDS)" = "$WHITE_TEXT_COLOR" ]; then
                # Select no
                log "Energy recover failed."
                tap $STAGE_BEGIN_NO_ENERGY_COORDS 0.1
                stage_begin_energy_failure="yes"

                fix_time
                break
            fi

            # Wait for stage to begin by checking pause button color
            # log "Wait for stage to begin..."
            for i in $(seq 60); do
                if [ "$(getcolor $PAUSE_BUTTON_COORDS)" == "$PAUSE_BUTTON_COLOR" ]; then
                    unset stage_begin_failure
                    break
                fi
            done

            if [ -n "$stage_begin_failure" ]; then
                log "FAILED: Stage begin failed. Waiting for manual correction."
                # Still wait for pause button to appear
                while [ "$(getcolor $PAUSE_BUTTON_COORDS)" != "$PAUSE_BUTTON_COLOR" ]; do
                    hold $START_BATTLE_BUTTON_COORDS 200 5
                done
            fi

            # Check if state reset is needed
            ((state_reset_count_target = stage_begin / 60 / RESET_STATE_INTERVAL))
            if ((state_reset_count_target > state_reset_count)); then
                log "State reset needed immediately! (#$reset_state_count_target)"
                reset_state
                ((state_reset_count = state_reset_count_target))
                log "Wait for stage to restart..."
                while [ "$(getcolor $PAUSE_BUTTON_COORDS)" != "$PAUSE_BUTTON_COLOR" ]; do
                    sleep 0.2
                done
            fi

            # Run the stage until the pause button disappear
            run_stage "$deploy_pattern"

            stage_end="$SECONDS"

            # Calculate statistics
            ((stage_time = stage_end - stage_begin))
            ((average = stage_end / ++clear_count))
            ((average_decimal = (stage_end * 100 / clear_count) % 100))
            ((total_hours = stage_end / 3600))
            ((total_minutes = (stage_end % 3600) / 60))
            ((rate = clear_count * 3600 / stage_end))
            ((rate_decimal = (clear_count * 360000 / stage_end) % 100))

            log "#%d: %ds, Avg %d.%02ds (%d.%02d/h), Total %dh%02dm" \
                "$clear_count" "$stage_time" \
                "$average" "$average_decimal" \
                "$rate" "$rate_decimal" \
                "$total_hours" "$total_minutes"

            # Quick energy recovery at the end of the stage
            if [ "$fix_timezone" = "strict" ]; then
                ts="$(date +%s)"
                ((hour_remain_sec = 3600 - ts % 3600))

                if ((hour_remain_sec < 10)); then
                    # Wait for the hour to pass
                    log "Wait ${hour_remain_sec}s for timezone switch..."
                    sleep $hour_remain_sec
                fi

                stage_end_hour="$(date +%H)"
                if ((stage_end_hour != start_hour)); then
                    should_reset_zone="yes"
                fi
            fi

            if ((round == repeat)) || [ -n "$should_reset_zone" ]; then
                reset_time
            fi

            # Quit
            exit_failure="yes"
            log "Exiting stage..."
            for i in $(seq 30); do
                if [ "$(getcolor $START_BATTLE_BUTTON_COORDS)" == "$START_BATTLE_BUTTON_COLOR" ]; then
                    unset exit_failure
                    break
                fi
                tap $RETURN_TO_MAP_COORDS 0.1
            done

            # Stage end manual correction
            if [ -n "$exit_failure" ]; then
                log "FAILED: The stage did not ended successfully. Waiting for manual correction."
                go_home 2
                go_cats 1
                while [ "$(getcolor $START_BATTLE_BUTTON_COORDS)" != "$START_BATTLE_BUTTON_COLOR" ]; do
                    hold $RETURN_TO_MAP_COORDS 200 5
                done
            fi

            if [ -n "$clear_limit" ] && ((clear_limit > 0)) && ((clear_count >= clear_limit)); then
                log "Clear limit reached ($clear_count), quitting."
                key 3 1  # Home
                key 26 1 # Lock screen
                return 0
            fi

            # Since energy is already recovered, restart the loop
            if [ -n "$should_reset_zone" ]; then
                unset should_reset_zone
                break
            fi
        done

        if [ -n "$stage_begin_energy_failure" ]; then
            log "Wait for network to expire"
            for j in $(seq 60); do
                if [ "$(getcolor $RED_TEXT_COORDS)" == "$RED_TEXT_COLOR" ]; then
                    break
                fi
                sleep 0.2
            done

            reset_time
            unset stage_begin_energy_failure
        fi

    done
}

if [ "$1" = "ticket" ]; then
    shift
    click_ticket "$@"
else
    main "$@"
fi
