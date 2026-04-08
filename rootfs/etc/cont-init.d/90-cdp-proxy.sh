#!/bin/sh
# Start CDP network proxy in the background.
# Chrome 144+ binds CDP to localhost only. socat forwards
# 0.0.0.0:9223 -> 127.0.0.1:9222 for cross-container CDP access.

nohup sh -c '
    while ! netstat -tlnp 2>/dev/null | grep -q ":9222"; do
        sleep 2
    done
    exec socat TCP-LISTEN:9223,fork,reuseaddr TCP:127.0.0.1:9222
' > /dev/null 2>&1 &

echo "CDP proxy will start when Chrome is ready on port 9222"
