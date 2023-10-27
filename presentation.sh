#!/usr/bin/env bash
# echo() { :; }  # comment this line to enable debuging

HOME="/home/otto"

# Directory containing the presentation files
PRESENTATION="$HOME/Presentation"

# Directory containing the control files
CONTROL="$HOME/Control"

# Binaries
SWAY_PATH="/home/otto/.nix-profile/bin"
SWAYSOCK=$($SWAY_PATH/sway --get-socketpath)
sleep 1;
SWAYMSG="$SWAY_PATH/swaymsg -q -s $SWAYSOCK "
SWAYMSG_LOUD="$SWAY_PATH/swaymsg -s $SWAYSOCK "
BIN_PATH="/etc/profiles/per-user/otto/bin"
LIBREOFFICE="$SWAYMSG -- exec $BIN_PATH/libreoffice --view --norestore --nologo "
IMAGEVIEWER="$SWAYMSG -- exec $BIN_PATH/imv-wayland -s full -f "
VIDEOPLAYER="$SWAYMSG_LOUD -- exec $BIN_PATH/mpv --fullscreen "

# Keep track of MD5sums in an associative array
declare -A fileHash

# Cleanup
rm -f $CONTROL/*

# Weekday Names
Weekdays=(Monday Tuesday Wednesday Thursday Friday Saturday Sunday)

function workspace {
	# Switches to a workspace, one of Vid, Img, Slide, Hide, Load
	$SWAYMSG -- workspace --no-auto-back-and-forth "$1" 
}

function reload_impress {
	echo "File hashes for $file differ, reloading."
	workspace Hide
	$SWAYMSG [title=\"Presenting: "$base"\"] kill
	sleep 1
	workspace Load
	$LIBREOFFICE "macro:///Standard.TV.Reload" "$REPLY"
	workspace Hide
	sleep 10
	workspace Slide
	$LIBREOFFICE "macro:///Standard.TV.Main" "$REPLY"
}

#Start Libreoffice on the load workspace, then Hide
workspace Load
$LIBREOFFICE &
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
			$SWAYMSG [title=\"$file.*\"] kill
			continue
		fi

		# Case insensitive file type determination
		extention="${file##*.}"
		ext="${extention,,}"

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
					$LIBREOFFICE "$REPLY"
				    sleep 1	
					workspace Hide
					sleep 15 # Make sure things load completely

				# Next check hash to see if we need to reload
				elif [ "$md5" != "$savedHash" ]; then
					reload_impress
				fi

				echo starting presentation "$file"
				workspace Slide
				$LIBREOFFICE "macro:///Standard.TV.Main" "$REPLY"
				fileHash["$file"]=$md5

				base=${file%.*}

				echo Waiting for end file

				# Wait for $CONTROLL/End file to appear at end of presentation
				while [ ! -f "$CONTROL/End" ]
				do
					sleep 1
					((rate_limit+=1))  # Limit the time spent calcing Hashes.  this isn't bitcoin.
					
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
				$SWAYMSG [title=\"Presenting: "$base"\"] kill
				workspace Hide
				sleep 2
				rm -f $CONTROL/End
				echo Presentation Finished
				;;

			jpeg | jpg | gif | png)
				# Standard image file types, add more here if needed.
				workspace Img
				$IMAGEVIEWER \""$REPLY"\"
				sleep 1
				if [ -n "${OldImg}" ]; then

					args=("$OldImg")

					OldPID=$(ps -C imv-wayland -o pid=,args= | grep "${args[@]}" | awk '{print $1}')
					echo "Attempting to kill $OldImg ($OldPID)"
					/run/current-system/sw/bin/kill $OldPID

				fi
				OldImg=$REPLY
				sleep 6
				;;

			avi | mov | mp4 | ogg | wmv | webm)
				workspace Vid
				VideoLen=$($BIN_PATH/ffprobe -i "$REPLY" -show_entries format=duration -v quiet -of csv="p=0")
				$VIDEOPLAYER \""$REPLY"\" 
				sleep "$VideoLen"
				sleep 2
				;;

			*) 
				echo Unsupported file "$file"
				;;
		esac

	done 9< <( find $PRESENTATION -type f -exec printf '%s\0' {} + )

done
