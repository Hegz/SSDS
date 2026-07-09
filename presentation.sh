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

LIBREOFFICE_BIN="$BIN_PATH/libreoffice"
IMAGEVIEWER_BIN="$BIN_PATH/imv-wayland"
VIDEOPLAYER_BIN="$BIN_PATH/mpv"

# Keep track of MD5sums in an associative array
declare -A fileHash

# Cleanup
rm -f "$CONTROL"/*

# Weekday Names
Weekdays=(Monday Tuesday Wednesday Thursday Friday Saturday Sunday)

# Helper function to log cleanly to journalctl
function log() {
    local priority="$1"
    local message="$2"
    logger -t presentation-script -p "user.$priority" "$message"
    echo "[$priority] $message"
}

# Function to load configuration parameters
function load_config {
    # Set default values first in case keys are missing
    ORDER_BY="alphabetical"
    ImageSleepTime=6

    if [ -f "$PRESENTATION/config.ini" ]; then
        while IFS='=' read -r key value; do
            [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] && eval "$key=\"$value\""
        done < "$PRESENTATION/config.ini"
        ORDER_BY=${ORDER_BY:-alphabetical}
        # Save the modification timestamp of the config file
        LAST_CONFIG_MOD=$(stat -c %Y "$PRESENTATION/config.ini" 2>/dev/null || echo 0)
        log notice "Configuration loaded/reloaded. ORDER_BY=$ORDER_BY, ImageSleepTime=$ImageSleepTime"
    else
        LAST_CONFIG_MOD=0
        log warning "config.ini not found at $PRESENTATION/config.ini. Using system defaults."
    fi
}

log info "Presentation script initialized."

# Initial configuration load on startup
load_config

function workspace {
	$SWAYMSG -- workspace --no-auto-back-and-forth "$1" 
}

function reload_impress {
	log notice "File hashes for $file differ, reloading."
	workspace Hide
	$SWAYMSG "[title=\"Presenting: $base\"]" kill
	sleep 1
	workspace Load
	if ! $SWAYMSG -- exec "$LIBREOFFICE_BIN" --view --norestore --nologo "macro:///Standard.TV.Reload" "'""$REPLY""'" 2>&1; then
		log err "Failed to execute LibreOffice Reload macro for $file"
	fi
	workspace Hide
	sleep 10
	workspace Slide
	if ! $SWAYMSG -- exec "$LIBREOFFICE_BIN" --view --norestore --nologo "macro:///Standard.TV.Main" "'""$REPLY""'" 2>&1; then
		log err "Failed to execute LibreOffice Main macro during reload for $file"
	fi
}

# Start Libreoffice on the load workspace, then Hide
workspace Load
$SWAYMSG -- exec "$LIBREOFFICE_BIN" --view --norestore --nologo &
workspace Hide

# main loop
while true 
do
	Today=$(date +%A)
	$BIN_PATH/killall imv-wayland
	$BIN_PATH/killall mpv
	OldImg=""

	while IFS= read -r -d '' -u 9
	do
		# CHECK FOR CONFIG CHANGES: Before displaying the next file, check if config.ini has changed
		if [ -f "$PRESENTATION/config.ini" ]; then
			CURRENT_CONFIG_MOD=$(stat -c %Y "$PRESENTATION/config.ini" 2>/dev/null || echo 0)
			if [ "$CURRENT_CONFIG_MOD" -ne "$LAST_CONFIG_MOD" ]; then
				log info "Detected change in config.ini. Reloading settings dynamically..."
				load_config
			fi
		fi

		file=$(basename "$REPLY")
		# Ignore files that are marked with a weekday name that is not todays.
		if [[ "$REPLY" != *"$Today"* ]]; then
			wrongDay=false
			for day in "${Weekdays[@]}"; do
				if [[ "$REPLY" ==  *"$day"* ]]; then
					log info "Skipping $file -- marked to play on $day."  
					wrongDay=true
					break
				fi
			done
			if [[ "$wrongDay" == "true" ]]; then
				continue
			fi
		fi

		log info "Attempting to display file: $REPLY"

		if ! [ -f "$REPLY" ]; then
			log warning "The file ($REPLY) is missing, skipping."
			$SWAYMSG "[title=\"$file.*\"]" kill
			continue
		fi

		extention="${file##*.}"
		ext="${extention,,}"
		base=${file%.*}

		case $ext in

			odp) 
				md5sum=$(md5sum "$REPLY")
				md5Array=("$md5sum")
				md5=${md5Array[0]}
				savedHash=${fileHash["$file"]}

				if ! $SWAYMSG_LOUD -t get_tree | grep -F -q "$file"; then
					log info "Document $file not preloaded. Loading now."
					workspace Load
					if ! $SWAYMSG -- exec "$LIBREOFFICE_BIN" --view --norestore --nologo "'""$REPLY""'" 2>&1; then
						log err "LibreOffice failed initial preload background window for $file"
					fi
				    sleep 1	
					workspace Hide
					sleep 15

				elif [ "$md5" != "$savedHash" ]; then
					reload_impress
				fi

				log info "Starting presentation: $file"
				workspace Slide
				if ! $SWAYMSG -- exec "$LIBREOFFICE_BIN" --view --norestore --nologo "macro:///Standard.TV.Main" "'""$REPLY""'" 2>&1; then
					log err "LibreOffice failed to open presentation view for $file"
				fi
				fileHash["$file"]=$md5

				while [ ! -f "$CONTROL/End" ]
				do
					sleep 1
					((rate_limit+=1))
					
					if [ "$rate_limit" -ge 15 ]; then
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
				log info "Presentation finished: $file"
				;;

			jpeg | jpg | gif | png)
				log info "Displaying image: $file"
				workspace Img
				if ! $SWAYMSG -- exec "$IMAGEVIEWER_BIN" -s full -f "'""$REPLY""'" 2>&1; then
					log err "Image viewer failed to open $file"
				fi
				sleep 1
				if [ -n "${OldImg}" ]; then
					args=("$OldImg")
					OldPID=$(ps -C imv-wayland -o pid=,args= | grep "${args[@]}" | awk '{print $1}')
					if [ -n "$OldPID" ]; then
						log info "Killing old image process for $OldImg ($OldPID)"
						/run/current-system/sw/bin/kill "$OldPID" 2>/dev/null
					fi
				fi
				OldImg=$REPLY
				sleep "$ImageSleepTime"
				;;

			avi | mov | mp4 | ogg | wmv | webm)
				log info "Playing video: $file"
				workspace Vid
				VideoLen=$($BIN_PATH/ffprobe -i "$REPLY" -show_entries format=duration -v quiet -of csv="p=0")
				
				# Fixed to target standard OpenGL pipelines and bypass Vulkan on the RPi4
				if ! $SWAYMSG_LOUD -- exec "$VIDEOPLAYER_BIN" \
					--fullscreen \
					--gpu-api=opengl \
					--hwdec=v4l2m2m \
					"'""$REPLY""'" 2>&1; then
					log err "Video player failed to play $file"
				fi
				sleep "$VideoLen"
				sleep 2
				;;

			*) 
				log warning "Unsupported file format skipped: $file"
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