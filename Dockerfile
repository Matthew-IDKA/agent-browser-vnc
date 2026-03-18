#
# agent-browser-vnc
#
# Browser automation container with visual remote access.
# Combines jlesage/chromium (noVNC) + Vercel's agent-browser CLI.
#
# View: http://host:5800 (noVNC) or VNC client on port 5900
# Control: agent-browser CLI via SSH or docker exec
# Debug: Chrome DevTools via CDP on port 9222
#
# SPDX-License-Identifier: GPL-3.0-only
# https://github.com/Matthew-IDKA/agent-browser-vnc
#

FROM jlesage/chromium:v26.03.2

ARG AGENT_BROWSER_VERSION=0.21.0

# Install Node.js (needed for agent-browser npm install) and curl
RUN add-pkg nodejs npm curl

# Install agent-browser globally
# The postinstall script downloads the musl-compatible Rust binary
RUN npm install -g agent-browser@${AGENT_BROWSER_VERSION}

# Skip agent-browser's own Chrome download -- we use the base image's Chromium
# Create a marker so agent-browser doesn't prompt for install
RUN mkdir -p /root/.agent-browser

# Add remote debugging port to Chromium launch params
COPY rootfs/ /

# Expose ports:
#   5800 - noVNC web viewer (from base image)
#   5900 - VNC protocol (from base image)
#   9222 - Chrome DevTools Protocol
EXPOSE 5800 5900 9222

# Environment defaults
ENV \
    AGENT_BROWSER_IDLE_TIMEOUT_MS=300000 \
    KEEP_APP_RUNNING=1
