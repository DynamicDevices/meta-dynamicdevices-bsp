#!/bin/bash
# E-ink Power Management Daemon
# Listens for shutdown/restart signals and handles power management

PIDFILE="/var/run/eink-power-daemon.pid"
LOGFILE="/var/log/eink-power-daemon.log"

log_message() {
    echo "$(date): $1" | tee -a "$LOGFILE"
}

# Signal handlers
handle_shutdown() {
    log_message "Received shutdown signal - preparing system..."
    
    # Run custom restart handler
    if [ -x "/usr/bin/eink-restart.sh" ]; then
        /usr/bin/eink-restart.sh
    fi
    
    log_message "Power management daemon shutting down"
    rm -f "$PIDFILE"
    exit 0
}

# Set up signal handlers
trap 'handle_shutdown' TERM INT QUIT

# Daemon main loop
daemon_loop() {
    log_message "E-ink power management daemon started (PID: $$)"
    echo $$ > "$PIDFILE"
    
    # Main daemon loop - just wait for signals
    while true; do
        sleep 10
        # Could add periodic power monitoring here
    done
}

# Start daemon
case "${1:-start}" in
    start)
        if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
            echo "Daemon already running"
            exit 1
        fi
        daemon_loop &
        ;;
    stop)
        if [ -f "$PIDFILE" ]; then
            kill "$(cat "$PIDFILE")" 2>/dev/null
            rm -f "$PIDFILE"
        fi
        ;;
    restart)
        $0 stop
        sleep 1
        $0 start
        ;;
    *)
        echo "Usage: $0 {start|stop|restart}"
        exit 1
        ;;
esac
