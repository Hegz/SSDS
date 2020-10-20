#!/bin/bash
# echo() { :; }  # comment this line to enable debuging

# Requires: xdotool wmctl


# Directory containing the presentation files
PRESENTATION="/home/ubuntu/Presentation"

# Directory containing the control files
CONTROL="/home/ubuntu/Control"

# Image file to use for hiding
HIDEIMAGE="/home/ubuntu/School_District_73.jpg"

# Binaries
LIBREOFFICE="/usr/bin/libreoffice"
IMAGEVIEWER="/usr/bin/feh"
WMCTRL="/usr/bin/wmctrl"
UNCLUTTER="/usr/bin/unclutter"
VIDEOPLAYER="/usr/bin/cvlc"

# Keep track of MD5sums in an associative array
declare -A fileHash

# Cleanup
rm -f $CONTROL/*

function activate {
	window=$@
	itter=0
	WinLoaded=true
	echo activating window: "$window"
	while ! $WMCTRL -l | grep -F -q "$window"
	do	
		echo Window \"$window\" not yet loaded.
		sleep 0.2
		let "itter++"

		# Winners don't loop to infinity.
		if [ $itter -gt 50 ]
		then
			# Failure to load window
			echo Kill all humans.
			killall soffice.bin
			killall feh
			killall cvlc
			WinLoaded=false
			break
		fi
	done
	
	if [ "$WinLoaded" = true ]; then
		echo window  \"$window\" has been activated

		$WMCTRL -a "$window"
		# sleep 1
	fi
}

function unhide {
	$WMCTRL -r $HIDEIMAGE -b remove,above
	$WMCTRL -r $HIDEIMAGE -b add,below
	$WMCTRL -r $HIDEIMAGE -b add,hidden
	echo Revealing All
}

function hide {
	$WMCTRL -a $HIDEIMAGE 
	$WMCTRL -r $HIDEIMAGE -b remove,below
	$WMCTRL -r $HIDEIMAGE -b add,above	
	$WMCTRL -r $HIDEIMAGE -b remove,hidden
	echo Hiding all windows
}

# Launch hiding window
$IMAGEVIEWER -ZxFYq $HIDEIMAGE &

hide

# Hide the mouse as much as possible
$UNCLUTTER -idle 0.01 -root &

Weekdays=(Monday Tuesday Wednesday Thursday Friday Saturday Sunday)

# main loop
while true 
do
	Today=$(date +%A)

	while IFS= read -r -d '' -u 9
	do
		file=$(basename "$REPLY")
		# Ignore files that are marked with a weekday name that is not todays.
		if [[ "$REPLY" != *"$Today"* ]]; then
			wrongDay=false
			for day in ${Weekdays[@]}; do
				if [[ "$REPLY" ==  *"$day"* ]]; then
					echo Skipping $REPLY -- marked to play on $day.  
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
			/usr/bin/wmctrl -c "$file"
			continue
		fi
				
		# Case insensitive file type determination
		extention="${file##*.}"
		ext="${extention,,}"

		case $ext in

			odp) 
				# Activate the next slide show in the series

				hide

				md5sum=$(md5sum "$REPLY")
				md5Array=($md5sum)
				md5=${md5Array[0]}
				savedHash=${fileHash["$file"]}
				echo saved hash [$savedHash]
				echo new hash "$md5" 

				# Check for Preload, if not load now.
				if ! /usr/bin/wmctrl -l | grep -F -q "$file"; then
					echo Document not loaded.  Loading now
					libreoffice --view --norestore --nologo --minimized "$REPLY" &
					sleep 1
					hide
					sleep 9 # Make sure things load completely
					/usr/bin/wmctrl -r $file -b add,shaded

				# Next check hash to see if we need to reload
				elif [ "$md5" != "$savedHash" ]; then
					echo "File hashes for $file differ, reloading."
					activate "$file"
					/usr/bin/libreoffice "macro:///Standard.TV.Reload" "$REPLY"
					fileHash["$file"]=$md5
				fi
				
				/usr/bin/wmctrl -r $file -b remove,shaded
				activate "$file"
				hide

				echo starting presentation $file
				/usr/bin/libreoffice "macro:///Standard.TV.Main" "$REPLY"

				base=${file%.*}
				echo base [$base]

				echo Waiting for end file
				
				kill $imagePid
				unhide

				activate "Presenting: $base"

				#/usr/bin/wmctrl -r $file -b add,shaded
				
				# Wait for $CONTROLL/End file to appear at end of presentation
				while [ ! -f "$CONTROL/End" ]
				do
					/usr/bin/wmctrl -a "Presenting: $base"
					sleep 0.2
				done
				hide

				echo Presentation Finished
				
				/usr/bin/wmctrl -c "Presenting: $base"
				
				hide
				;;

			jpeg | jpg | gif | png)
				# Standard image file types, add more here if needed.
				oldPid=$imagePid
				$IMAGEVIEWER -ZxFYq "$REPLY" &
				imagePid=$!
				sleep 1
				kill $oldPid
				sleep 6

				;;

			avi | mov | mp4 | ogg | wmv | webm)
				echo playing video $file 
				$CVLC --no-video-title --fullscreen --video-on-top --play-and-exit "$REPLY"
				;;

			*) 
				echo Unsupported file $file
				;;
		esac

	done 9< <( find $PRESENTATION -type f -exec printf '%s\0' {} + )
done
