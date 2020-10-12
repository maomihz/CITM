getcolor() {
	w="${4:-2340}"
	h="${5:-1080}"
	x="$1"
	y="$2"
	len="${3:-1}"

	offset="$(( (y * w + x + 4) * 4 ))"
	screencap | head -c "$((offset + len * 4))" | tail -c "$((len * 4))" | xxd -p
	#screencap | dd bs=4 count="$len" skip="$offset" 2>/dev/null | xxd -p | tr -d ' \n'
}

getcolor2() {
	getcolor "$1" "$2" "$3" 1080 2340
}

go() {
	am start -W -n "$1" --activity-single-top --activity-no-animation >/dev/null
	[ -n "$2" ] && sleep "$2"
}

go_settings() {
	go 'com.android.settings/.Settings$DateTimeSettingsActivity' "$1"
}

go_cats() {
	go 'jp.co.ponos.battlecats/.MyActivity' "$1"
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
	echo "$0 <repeat> <energytype> <deploy_pattern> <fix_timezone>"
	exit 0
}

log() {
	echo $(date +"[%F %T]") $@
}

# UI Colors
PAUSE_BUTTON_COLOR="ffcc00ff"  # Top left of battle screen
AUTO_DATE_TIME_ENABLED_COLOR="2093eeff"  # Blue on switch
START_BATTLE_BUTTON_COLOR="ffc200ff"
WHITE_TEXT_COLOR="ffffffff"
RED_TEXT_COLOR="ff0000ff"

# Cat deploy row settings
CAT_DEPLOY_X_OFFSET=750
CAT_DEPLOY_Y_SPACING=200
CAT_DEPLOY_Y_OFFSET=925
DAY_OFFSET="-2"

# Date/time settings
DATE_X_OFFSET=245
DATE_Y_OFFSET=1125
DATE_X_SPACING=99
DATE_Y_SPACING=105

# Number of seconds to wait for screen switch
SWITCH_SCREEN_DELAY=0.5

# Number of minutes to reset state
RESET_STATE_INTERVAL=90  

run_stage() {
	deploy_pattern="$1"
	current_row=0

	while true; do
		# Deploy cats loop
		for i in $deploy_pattern; do
			if [ "$i" = "u" ]; then
				log "upgrade"
				hold 167 907 100 0.1
				continue
			fi

			row="$(((i-1) / 5))"
			idx="$(((i-1) % 5))"

			# Check if stage ended
			if [ "$(getcolor 44 88)" != "$PAUSE_BUTTON_COLOR" ]; then
				log "Stage ended."
				return 0
			fi


			# Switch row if necessary
			if [ "$current_row" != "$row" ]; then
				input swipe 75 500 75 400 200
				current_row="$((1 - current_row))"
			fi

			# Click to deploy unit
			cat_x="$((idx * CAT_DEPLOY_Y_SPACING + CAT_DEPLOY_X_OFFSET))"
			cat_y="$CAT_DEPLOY_Y_OFFSET"

			(input tap "$cat_x" "$cat_y" &)
			sleep 0.05
		done
	done
}

fix_time() {
	log 'Trying to fix time...'
	go_settings 0.2

	# Check if automatic date time is checked
	if [ "$(getcolor2 996 379)" != "$AUTO_DATE_TIME_ENABLED_COLOR" ]; then
		tap 996 379 0.1
	fi

	go_cats 0.2
}

reset_time() {
	# Calculate date and time
	current="$(date +%s)"
	current_day="$(date +%e)"

	before="$((current + DAY_OFFSET * 86400))"
	before_day="$(date -d @$before +%e)"
	before_weekday="$(date -d @$before +%u)"

	date_row=$(( (before_day + 5 - before_weekday % 7) / 7 ))
	date_col=$((before_weekday % 7))

	date_x=$((date_col * DATE_X_SPACING + DATE_X_OFFSET))
	date_y=$((date_row * DATE_Y_SPACING + DATE_Y_OFFSET))

	log "Date pos: $date_row, $date_col ($date_x, $date_y)"

	unset zone_index

	if [ -n "$fix_timezone" ]; then
		# Figure out the timezone
		current_hour="$(date +%H)"
		current_zone="$(date +%z)"

		if (( current_hour != start_hour )); then
			next_zone="$(( current_zone / 100 - 1 ))"

			log "Change timezone to $next_zone"

			if (( next_zone < -12 )); then
				log "Cannot fix timezone anymore!"
			else
				# Figure out how many times to press down
				if (( next_zone == 0 )); then
					zone_index=0
				elif (( next_zone < 0 )); then
					zone_index=$(( next_zone + 13 ))
				else
					zone_index=$(( next_zone + 12 ))
				fi
			fi

			if (( next_zone == -12 )); then
				log "There is no way to fix timezone anymore. Just give up."
				unset fix_timezone
			fi

		fi
	fi

	go_settings "$SWITCH_SCREEN_DELAY"

	# Network-provided time off
	tap 930 382 0.1

	# Date menu
	tap 930 582 0.1

	# Turn to last month
	if (( current_day + DAY_OFFSET <= 0 )); then
		tap "$DATE_X_OFFSET" "$((DATE_Y_OFFSET - 2 * DATE_Y_SPACING))" 0.1
	fi

	tap "$date_x" "$date_y" 0.1
	tap 834 1770 0.1  # ok

	if [ -n "$zone_index" ]; then
		tap 930 1200 0.1  # Set timezone
		tap 930 456 0.1  # Set by UTF offset
		for i in $(seq -1 $zone_index); do
			key 20 0.05  # Down arrow
		done
		key 66 0.1  # Enter
		key 4 0.3  # Back
	fi

	go_cats "$SWITCH_SCREEN_DELAY"
	go_settings "$SWITCH_SCREEN_DELAY"

	# Network-provided time on
	tap 930 382 0.1

	go_cats 0.2
}

# Reset the application state by closing all background applications
reset_state() {
	am force-stop 'jp.co.ponos.battlecats' >/dev/null
	am force-stop 'com.android.settings' >/dev/null
	go_settings 0.5

	go_cats 5

	# right, right, enter
	while [ "$(getcolor 1271 463)" != "ffffffff" ]; do
		sleep 1
	done

	key 22 0.2
	key 22 0.2
	key 66 0.2
}

click_ticket() {
	ticket_type="$1"
	while true; do
		i=1
		while [ "$(getcolor 2260 830)" != "ffffffff" ]; do
			((i++ % 10 == 0)) && input tap 1809 918
			sleep 0.1
		done

		log "Tap draw"
		hold 2260 830 200 0.4

		log "Check full?"
		if [ "$(getcolor 1557 710)" = "ffffffff" ]; then
			log "Storage full."
			hold 1557 710 200 0.5
			tap 294 923 1
			hold 1473 1035 200 0.5
			tap 911 665 0.5
			tap 911 665 0.5

			if [ "$ticket_type" = "silver" ]; then
				hold 1115 1035 200 0.5
				tap 1620 665 0.5
				tap 941 895 1
				hold 90 985 200 0.5
			fi

			hold 90 985 200 1
			continue
		fi

		sleep 4.5
		log "Check result?"
		for i in $(seq 22); do
			(input tap 1809 918 & sleep 0.25)
		done
		sleep 0.6
	done
}


main() {
	repeat="${1:-3}"
	energytype="${2:-1}"
	deploy_pattern="${3}"
	fix_timezone="${4}"

	if [ "${#energytype}" != 1 ]; then
		fix_timezone="${deploy_pattern}"
		deploy_pattern="${energytype}"
		energytype=1
	fi

	# Display help
	if [ -z "$repeat" ] || [ -z "$energytype" ] || [ -z "$deploy_pattern" ]; then
		help "Missing arguments."
	fi

	clear_count=0
	average=120
	start_time="$(date +%s)"
	start_hour="$(date +%H)"
	reset_state_count=0

	log "===  Battle Cats  ==="
	log "Repeat = $repeat"
	log "Energy Type: $energytype"
	log "Cat deploy pattern: $deploy_pattern"
	log "Fix timezone: \"$fix_timezone\""
	if [ -n "$fix_timezone" ]; then
		log "Fix hour: $start_hour, current zone: $start_zone"
	fi

	am force-stop 'com.android.settings' >/dev/null
    log 'Kill com.android.settings'

	while true; do
		for round in $(seq 1 "$repeat"); do
			# Check for insufficient energy
			if [ "$(getcolor 2274 534)" = "fc0101ff" ]; then
				log "Insufficient Energy."
				energytype=1
				if [ -z "$energyrecovered" ]; then
					break
				fi

				if (( round == 1 )); then
					log "Energy recover failed!"
					fix_time
					break
				fi
			fi

			# Check for strict timezone
			if [ "$fix_timezone" = "strict" ] && ( (( 3600 - $(date +%s) % 3600 <= average )) || (( $(date +%H) != start_hour )) ); then
				sec="$(( 3600 - $(date +%s) % 3600 ))"
				(( sec < 300 )) && sleep "$sec"
				log "Wait for event hour $start_hour to finish... (${sec}s)"
				break
			fi

			# Start
			log "Start Game (#$round)"
			tap 2260 776 3

			stage_begin="$(date +%s)"

			# Energy is not successfully recovered
			if [ "$(getcolor 1489 705)" = "$WHITE_TEXT_COLOR" ]; then
				# Select no
				log "Energy recover failed."
				tap 1489 705 0.1

				[ -z "$energyrecovered" ] || fix_time
				break
			fi

			# Wait for stage to begin
			stage_begin_success=false
            log "Wait for stage to begin..."
			for i in $(seq 60); do
				if [ "$(getcolor 44 88)" == "$PAUSE_BUTTON_COLOR" ]; then
					stage_begin_success=true
					break
				fi
			done

			if [ "$stage_begin_success" = "false" ]; then
				log "Stage begin failed. Waiting for manual correction."
				while [ "$(getcolor 44 88)" != "$PAUSE_BUTTON_COLOR" ]; do
					sleep 2
				done
			fi

			# Check if state reset is needed
            (( state_reset_count_target = (stage_begin - start_time) / 60 / RESET_STATE_INTERVAL ))
			if (( state_reset_count_target > state_reset_count )); then
				log "State reset needed immediately! (#$reset_state_count_target)"
				reset_state
				((state_reset_count = state_reset_count_target))
                log "Wait for stage to restart..."
				while [ "$(getcolor 44 88)" != "$PAUSE_BUTTON_COLOR" ]; do
					sleep 0.2
				done
			fi

			run_stage "$deploy_pattern"

			stage_end="$(date +%s)"
			((clear_count++))
			average=$(( (stage_end - start_time) * 100 / clear_count ))

			log "Clear time: $((stage_end - stage_begin))s"
			log "Average: ${average}s ($clear_count)"
			#log "$round / $repeat"

			if (( round == "$repeat" )); then
				sleep 2
				reset_time
				energyrecovered="true"
			fi

			# Quit
			exit_success="false"
            log "Exiting stage..."
			for i in $(seq 60); do
				if [ "$(getcolor 1837 713)" == "$START_BATTLE_BUTTON_COLOR" ]; then
					exit_success="true"
					break
				fi
				(input tap 2263 53 &)
			done

			# Stage end manual correction
			if [ "$exit_success" = "false" ]; then
				log "The stage does not ended successfully. Waiting for manual correction."
				while [ "$(getcolor 1837 713)" != "$START_BATTLE_BUTTON_COLOR" ]; do
					sleep 2
				done
			fi
			# sleep 1
		done

		if (( round != "$repeat" )); then
			log "Wait for network to expire"
			# 1888 443
			# 1875 549
			for j in $(seq 60); do
				if [ "$(getcolor 2151 554)" == "$RED_TEXT_COLOR" ] || [ "$(getcolor 2151 455)" == "$RED_TEXT_COLOR" ]; then
					break
				fi
				sleep 0.2
			done

			reset_time
			energyrecovered=true
		fi
	done
}

if [ "$1" = "ticket" ]; then
	shift
	click_ticket "$@"
else
	main "$@"
fi
