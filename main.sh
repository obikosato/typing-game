#!/bin/sh

w_x=$(tput lines)
w_y=$(tput cols)
x_position=$((w_x / 3))
y_position=$((w_y / 3))

current_dir="$(
	d=${0%/*}/
	[ "_$d" = "_$0/" ] && d='./'
	cd "$d" || exit
	pwd
)"

file_name="$current_dir/words.csv"

display_mission() {
	clear

	mission=$current_dir/mission.txt

	###  set iteration  ###
	line_count=$(grep -cvE '^[[:space:]]*$' "$mission")

	for itry in $(seq 1 "${line_count}"); do
		message=$(read_specific_line "$mission" "${itry}" | tr -d '@')
		if [ "$itry" -eq 1 ]; then
			tput cup $((x_position + itry - 1)) $((y_position + 5))
		else
			tput cup $((x_position + itry + 1)) "$y_position"
		fi
		echo "$message"
	done

	tput cup $((x_position + 12)) "$y_position"
	echo "[q] to quit"

	tput cup $((x_position + 14)) "$y_position"
	echo "[Enter] to start typing game"

	# shellcheck disable=SC3045
	read -s -n 1 key
	if [ "${key}" = "q" ]; then
		clear
		exit
	fi

	clear
}

read_specific_line() {
	file="$1"
	line_number="$2"

	if [ ! -e "$file" ]; then
		echo "error: file '$file' is not found."
		return 1
	fi

	if ! [ "$line_number" -eq "$line_number" ] 2> /dev/null; then
		echo "error: '$line_number' is not a number."
		return 1
	fi

	line_content=$(sed -n "${line_number}p" "$file")
	if [ -n "$line_content" ]; then
		echo "$line_content"
	else
		echo ""
	fi
}

display_str() {
	result=$(read_specific_line "$file_name" "$1" | cut -d ',' -f 1)
	echo "$result"
}

typing_str() {
	result=$(read_specific_line "$file_name" "$1" | cut -d ',' -f 2)
	echo "$result"
}

display_score() {
	clear

	tput cup "$x_position" "$y_position"
	echo "     --- Your Score ---"

	time=$(echo "scale=3;${stop}-${start}" | bc)

	tput cup $((x_position + 2)) "$y_position"
	if [ "$(uname)" = "Darwin" ]; then
		echo "total time        : ${time} [sec]"

	elif [ "$(uname)" = "Linux" ]; then
		echo "total time        : ${time} [msec]"
	fi

	tput cup $((x_position + 4)) "$y_position"
	echo "total characters  : ${characters} [characters]"

	tput cup $((x_position + 6)) "$y_position"
	echo "# of typing       : ${typing} [typing]"

	tput cup $((x_position + 8)) "$y_position"
	echo "accuracy          : ""$(echo "scale=3;${characters}/${typing}*100" | bc)" "[%]"

	tput cup $((x_position + 10)) "$y_position"
	echo "typing speed      : ""$(echo "scale=3;${time}/${characters}" | bc)" "[sec/character]"

	tput cup $((x_position + 12)) "$y_position"
	echo "typing speed      : ""$(echo "scale=3;${characters}/${time}" | bc)" "[characters/sec]"

	tput cup $((x_position + 14)) "$y_position"
	# shellcheck disable=SC3045
	read -p "hit return key" _
	clear
}

set_timer() {
	if [ "$(uname)" = "Darwin" ]; then
		printf '%.3f' "$(date '+%s')"
	elif [ "$(uname)" = "Linux" ]; then
		printf '%.3f' "$(date '+%s.%N')"
	fi
}

play_game() {
	###  set invisible cursor  ###
	tput civis

	###  set terminal in raw mode  ###
	stty raw -echo

	###  # of characters you type  ###
	characters=0

	###  # of typing  ###
	typing=0

	###  start timer  ###
	start=$(set_timer)

	###  set iteration  ###
	line_count=$(grep -cvE '^[[:space:]]*$' "$file_name")

	for itry in $(seq 1 "$line_count"); do

		###  clear display  ###
		clear

		###  set typing word  ###
		string="$(typing_str "$itry")"
		if [ "${#string}" = 0 ]; then
			continue
		fi

		###  increase total # of characters  ###
		characters=$((characters + ${#string}))

		###  print information  ###
		tput cup "$x_position" "$y_position"
		echo "Type following sentence (type '|' to quit)"

		tput cup $((x_position + 3)) "$y_position"
		display_str "$itry"

		###  stop if # of characters of ${string} is zero  ###
		while [ ${#string} -gt 0 ]; do

			###  set length of the string  ###
			string_length=${#string}

			###  print the remaining string  ###
			tput cup $((x_position + 5)) $((y_position + string_length))
			printf " "

			tput cup $((x_position + 5)) "$y_position"
			echo "${string}"

			flag=0

			while [ "${flag}" -eq 0 ]; do

				###  increase total # of typing  ###
				typing=$((typing + 1))

				###  real time input => ${char}  ###
				tput cup $((x_position + 5)) "$y_position"
				tput cnorm
				char=$(dd bs=1 count=1 2> /dev/null)
				tput civis

				if [ "$(echo "$string" | cut -c 1)" = "$char" ]; then
					flag=1
				elif [ "${char}" = "|" ]; then
					stop=$(set_timer)
					stty -raw echo
					tput cnorm
					return
				else
					printf '\007'
				fi

			done

			### if the first character of ${string} is blank... ###
			if [ "${string#"${string%?}"}" = " " ]; then
				string=$(echo "$string" | sed -e 's/^[[:space:]]//')
			### cut the first character of ${string}... ###
			else
				string=$(echo "$string" | sed -e 's/^.//')
			fi

		done

	done

	###  stop timer (in mill-seconds)  ###
	stop=$(set_timer)

	###  unset terminal in raw mode  ###
	stty -raw echo

	###  set visible cursor  ###
	tput cnorm

	###  display score  ###
	display_score
}

###  main  ###
while :; do
	display_mission
	play_game
done
