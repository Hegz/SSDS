#!/usr/bin/env bash
# echo() { :; }  # comment this line to enable debugging

HOME="/home/otto"

# Directory containing the presentation files
PRESENTATION="$HOME/Presentation"

# Directory containing the control files
CONTROL="$HOME/Control"

# Binaries
SWAY_PATH="/home/otto/.nix-profile/bin"
SWAYSOCK=$($SWAY_PATH/sway --get-socketpath)
sleep 1;
SWAYMSG="$SWAY_PATH/swaymsg -q -s $SWAYSOCK"
SWAYMSG_LOUD="$SWAY_PATH/swaymsg -s $SWAYSOCK"
BIN_PATH="/etc/profiles/per-user/otto/bin"

# REMOVED internal 'exec' from variables to allow clean argument passing
LIBREOFFICE_BIN="$BIN_PATH/libreoffice"
IMAGEVIEWER_BIN="$BIN_PATH/imv-wayland"
VIDEOPLAYER_BIN="$BIN_PATH/mpv"
ImageSleepTime=6

# Keep track of MD5sums in an associative array
declare -A fileHash

# Cleanup
rm -f "$CONTROL"/*

# Weekday Names
Weekdays=(Monday Tuesday Wednesday Thursday Friday Saturday Sunday)

# Set defaults if config is missing.
ORDER_BY="alphabetical"
ImageSleepTime=6

# Load cfg values (FIXED: points to $PRESENTATION/config.ini now)
if [ -f "$PRESENTATION/config.ini" ]; then
    while IFS='=' read -r key value; do
        [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] && eval "$key=\"$value\""
    done < "$PRESENTATION/config.ini"
    ORDER_BY=${ORDER_BY:-alphabetical}
fi

function workspace {
	# Switches to a workspace, one of Vid, Img, Slide, Hide, Load
	$SWAYMSG -- workspace --no-auto-back-and-forth "$1" 
}

function reload_impress {
	echo "File hashes for $file differ, reloading."
	workspace Hide
	$SWAYMSG "[title=\"Presenting: $base\"]" kill
	sleep 1
	workspace Load
	$SWAYMSG -- exec "$LIBREOFFICE_BIN" --view --norestore --nologo "macro:///Standard.TV.Reload" "$REPLY"
	workspace Hide
	sleep 10
	workspace Slide
	$SWAYMSG -- exec "$LIBREOFFICE_BIN" --view --norestore --nologo "macro:///Standard.TV.Main" "$REPLY"
}

# Start Libreoffice on the load workspace, then Hide
workspace Load
$SWAYMSG -- exec "$LIBREOFFICE_BIN" --view --norestore --nologo &
workspace Hide

# main loop
while true 
do
	# Get todays Weekday name
	Today=$(date +%A)
	$BIN_PATH/killall imv-wayland
	$BIN_PATH/killall mpv
	OldImg=""

	while IFS= read -r -d '' -u 9
	do
		file=$(basename "$REPLY")
		# Ignore files that are marked with a weekday name that is not todays.
		if [[ "$REPLY" != *"$Today"* ]]; then
			wrongDay=false
			for day in "${Weekdays[@]}"; do
				if [[ "$REPLY" ==  *"$day"* ]]; then
					echo Skipping "$REPLY" -- marked to play on "$day".  
					wrongDay=true
					break
				fi
			done
			if [[ "$wrongDay" == "true" ]]; then
				continue
			fi
		fi

		echo "Processing $REPLY"

		if ! [ -f "$REPLY" ]; then
			echo "The file ($REPLY) is missing, jumping to next file"
			$SWAYMSG "[title=\"$file.*\"]" kill
			continue
		fi

		# Case insensitive file type determination
		extention="${file##*.}"
		ext="${extention,,}"
		base=${file%.*}

		case $ext in

			odp) 
				# Activate the next slide show in the series

				md5sum=$(md5sum "$REPLY")
				md5Array=("$md5sum")
				md5=${md5Array[0]}
				savedHash=${fileHash["$file"]}

				# Check for Preload, if not load now.
				if ! $SWAYMSG_LOUD -t get_tree | grep -F -q "$file"; then
					echo Document not loaded.  Loading now
					workspace Load
					$SWAYMSG -- exec "$LIBREOFFICE_BIN" --view --norestore --nologo "$REPLY"
				    sleep 1	
					workspace Hide
					sleep 15 # Make sure things load completely

				# Next check hash to see if we need to reload
				elif [ "$md5" != "$savedHash" ]; then
					reload_impress
				fi

				echo starting presentation "$file"
				workspace Slide
				$SWAYMSG -- exec "$LIBREOFFICE_BIN" --view --norestore --nologo "macro:///Standard.TV.Main" "$REPLY"
				fileHash["$file"]=$md5

				echo Waiting for end file

				# Wait for $CONTROL/End file to appear at end of presentation
				while [ ! -f "$CONTROL/End" ]
				do
					sleep 1
					((rate_limit+=1))  # Limit the time spent calcing Hashes.
					
					if [ "$rate_limit" -ge 15 ]; then
						# Recalc md5sum reload if needed.
						rate_limit=0
                        md5sum=$(md5sum "$REPLY")
				        md5Array=("$md5sum")
						md5=${md5Array[0]}
						savedHash=${fileHash["$file"]}

						if [ "$md5" != "$savedHash" ]; then
							reload_impress
							fileHash["$file"]=$md5
						fi
					fi
				done

				workspace Hide
				$SWAYMSG "[title=\"Presenting: $base\"]" kill
				workspace Hide
				sleep 2
				rm -f "$CONTROL/End"
				echo Presentation Finished
				;;

			jpeg | jpg | gif | png)
				# Standard image file types
				workspace Img
				$SWAYMSG -- exec "$IMAGEVIEWER_BIN" -s full -f "$REPLY"
				sleep 1
				if [ -n "${OldImg}" ]; then
					args=("$OldImg")
					OldPID=$(ps -C imv-wayland -o pid=,args= | grep "${args[@]}" | awk '{print $1}')
					echo "Attempting to kill $OldImg ($OldPID)"
					/run/current-system/sw/bin/kill "$OldPID"
				fi
				OldImg=$REPLY
				sleep "$ImageSleepTime"
				;;

			avi | mov | mp4 | ogg | wmv | webm)
				workspace Vid
				VideoLen=$($BIN_PATH/ffprobe -i "$REPLY" -show_entries format=duration -v quiet -of csv="p=0")
				$SWAYMSG_LOUD -- exec "$VIDEOPLAYER_BIN" --fullscreen "$REPLY"
				sleep "$VideoLen"
				sleep 2
				;;

			*) 
				echo Unsupported file "$file"
				;;
		esac

	done 9< <( if [ "$ORDER_BY" = "random" ]; then
		find "$PRESENTATION" -type f -exec printf '%s\0' {} + | 
			while IFS= read -r -d '' file; do
				printf '%s\t%s\n' "$(sha256sum <<< "$file" | cut -d' ' -f1)" "$file"
			done | sort | cut -f2-
	elif [ "$ORDER_BY" = "date_newest" ]; then
		find "$PRESENTATION" -type f -printf '%T@\t%p\0' | sort -z -n -r | cut -z -f2-
	elif [ "$ORDER_BY" = "date_oldest" ]; then
		find "$PRESENTATION" -type f -printf '%T@\t%p\0' | sort -z -n | cut -z -f2-
	else
		find "$PRESENTATION" -type f -exec printf '%s\0' {} + | sort -z
	fi )
done
