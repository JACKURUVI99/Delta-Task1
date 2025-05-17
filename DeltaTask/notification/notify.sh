#!/bin/bash
# notify.sh - Complete notification system with daemon support

# Configuration
PORT=9999
NOTIFICATION_DIR="/tmp/notifications"
SUBSCRIPTION_FILE="/root/DeltaTask/subscriptionModel/subscriptions.yaml"
LOG_FILE="/var/log/notify.log"
PID_FILE="/var/run/notify_daemon.pid"
NC_TIMEOUT=60

# Initialize system
init_notification_system() {
    [ ! -f "$SUBSCRIPTION_FILE" ] && touch "$SUBSCRIPTION_FILE"
    echo "$(date) - Notification system accessed by $(whoami)" >> "$LOG_FILE"
}

# Get user's home directory
get_user_home() {
    local username="$1"
    if id -nG "$username" | grep -qw "g_user"; then
        echo "/home/users/$username"
    elif id -nG "$username" | grep -qw "g_author"; then
        echo "/home/authors/$username"
    elif id -nG "$username" | grep -qw "g_mod"; then
        echo "/home/mods/$username"
    elif id -nG "$username" | grep -qw "g_admin"; then
        echo "/home/admin/$username"
    else
        echo ""
    fi
}

# Send notification to subscribers
send_notification() {
    local author="$1"
    local message="$2"
    
    echo "$(date) - Sending notification from $author: $message" >> "$LOG_FILE"
    
    # Get subscribers
    subscribers=$(yq e ".subscriptions[] | select(.author == \"$author\") | .users[]" "$SUBSCRIPTION_FILE" 2>/dev/null)
        
    for user in $subscribers; do
        user_home=$(get_user_home "$user")
        [ -z "$user_home" ] && continue
        
        notification_file="$user_home/notifications.log"
        touch "$notification_file"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> "$notification_file"
    done
}

# Start daemon
start_daemon() {
    if [ -f "$PID_FILE" ]; then
        echo "Daemon is already running"
        return
    fi

    echo "Starting notification daemon..."
    nohup bash -c "while true; do nc -l -p $PORT -w $NC_TIMEOUT | while read line; do echo \"\$line\" >> \"$LOG_FILE\"; done; done" >/dev/null 2>&1 &
    echo $! > "$PID_FILE"
}

# Stop daemon
stop_daemon() {
    [ -f "$PID_FILE" ] && kill $(cat "$PID_FILE") && rm -f "$PID_FILE"
    echo "Daemon stopped"
}

# Main execution
case "$1" in
    --start-daemon)
        start_daemon
        ;;
    --stop-daemon)
        stop_daemon
        ;;
    --new-article)
        [ -z "$2" ] || [ -z "$3" ] && { echo "Missing arguments"; exit 1; }
        send_notification "$2" "New article: $3"
        ;;
    --check)
        user_home=$(get_user_home "$(whoami)")
        [ -z "$user_home" ] && { echo "Cannot determine home directory"; exit 1; }
        
        notification_file="$user_home/notifications.log"
        [ -f "$notification_file" ] && cat "$notification_file" || echo "No notifications"
        ;;
    *)
        echo "Usage:"
        echo "  $0 --start-daemon"
        echo "  $0 --stop-daemon"
        echo "  $0 --new-article <author> <title>"
        echo "  $0 --check"
        exit 1
        ;;
esac