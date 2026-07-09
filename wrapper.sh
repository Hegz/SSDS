#!/usr/bin/env bash

cd /home/otto

# Helper function to log wrapper status cleanly to journalctl
function log_wrapper() {
    local priority="$1"
    local message="$2"
    logger -t presentation-wrapper -p "user.$priority" "$message"
    echo "[$priority] $message"
}

log_wrapper notice "Presentation wrapper service started."

while true; do
    log_wrapper info "Starting presentation script execution loop..."
    
    # Run the presentation script, capturing stdout/stderr and routing to logger
    # This ensures anything the main script misses is still caught!
    /home/otto/ssds/presentation.sh 2>&1 | logger -t presentation-script -p user.notice

    # If the script finishes or crashes, catch the exit code
    EXIT_CODE=${PIPESTATUS[0]}
    
    log_wrapper warning "Presentation script exited unexpectedly with code $EXIT_CODE. Restarting in 3 seconds..."
    sleep 3
done