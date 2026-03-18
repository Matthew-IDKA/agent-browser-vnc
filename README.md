# agent-browser-vnc

Docker container that lets AI agents control a browser while you watch.

Combines [jlesage/chromium](https://github.com/jlesage/docker-chromium) (Chromium + noVNC) with Vercel's [agent-browser](https://github.com/vercel-labs/agent-browser) CLI in a single container. Your AI agent sends commands, the browser executes them, and you see everything happen in real time through a web viewer.

## The Problem

AI coding agents (Claude Code, Cursor, Copilot) need browser access for testing, scraping, and interacting with web apps. The existing options force a tradeoff:

- **Playwright MCP / agent-browser** run headless -- you can't see what the browser is doing
- **Claude in Chrome** uses your local browser -- ties up your machine and can't run on a server
- **Screenshot-based tools** are slow, expensive, and give you static snapshots instead of a live view

## The Solution

Run the browser on any Docker host (home server, VPS, CI). The agent controls it via CLI. You watch and intervene via a web viewer. Three access paths, one container:

| Path | Port | Purpose |
|------|------|---------|
| **noVNC** | 5800 | Watch live in any web browser. Click, type, solve CAPTCHAs. |
| **agent-browser CLI** | -- | AI agent sends commands via `docker exec` or SSH |
| **Chrome DevTools** | 9222 | Attach DevTools from another machine for DOM/network inspection |

## Quick Start

```bash
git clone https://github.com/Matthew-IDKA/agent-browser-vnc.git
cd agent-browser-vnc
docker compose up -d
```

Open `http://localhost:5800` to see the browser. Then control it:

```bash
# Navigate
docker exec agent-browser-vnc agent-browser --cdp 9222 open https://example.com

# Get interactive elements (token-efficient refs)
docker exec agent-browser-vnc agent-browser --cdp 9222 snapshot -i
# Output:
# - heading "Example Domain" [level=1, ref=e1]
# - link "Learn more" [ref=e2]

# Click by ref
docker exec agent-browser-vnc agent-browser --cdp 9222 click @e2

# Fill a form field
docker exec agent-browser-vnc agent-browser --cdp 9222 fill @e3 "hello@example.com"

# Take a screenshot
docker exec agent-browser-vnc agent-browser --cdp 9222 screenshot page.png
```

## Remote Server Usage

For a headless server (Unraid, Proxmox, VPS):

```bash
# AI agent controls the browser via SSH
ssh user@server 'docker exec agent-browser-vnc agent-browser --cdp 9222 snapshot -i'
ssh user@server 'docker exec agent-browser-vnc agent-browser --cdp 9222 click @e2'

# You watch in your browser
open http://server:5800
```

### Claude Code Skill Example

Create `.claude/skills/browser.md` in your project:

```markdown
## Browser Control

Control a remote browser via agent-browser on the Docker host.

Commands are run via: ssh user@server 'docker exec agent-browser-vnc agent-browser --cdp 9222 <command>'

Key commands:
- open <url> -- navigate to a URL
- snapshot -i -- get interactive elements with refs
- click @ref -- click an element
- fill @ref "text" -- fill a form field
- get url -- get current URL
- get text @ref -- get element text
- screenshot <path> -- take a screenshot
```

## Authentication Workflow

Need to use a logged-in session? Log in manually, then let the agent take over:

1. Open `http://server:5800` in your browser
2. Log into the service through the noVNC viewer (you're clicking in a real browser)
3. The session persists in the `/config/chromium` volume
4. agent-browser commands now operate in the authenticated context

This is the key advantage over headless-only tools -- you handle the login, CAPTCHA, or 2FA once, and the agent works in that session going forward.

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TZ` | `Etc/UTC` | Timezone |
| `KEEP_APP_RUNNING` | `1` | Auto-restart Chromium on crash |
| `DISPLAY_WIDTH` | `1920` | Virtual display width |
| `DISPLAY_HEIGHT` | `1080` | Virtual display height |
| `AGENT_BROWSER_IDLE_TIMEOUT_MS` | `300000` | Kill browser after 5 min idle (set `0` to disable) |
| `CHROMIUM_APP_URL` | (empty) | Launch Chromium in app mode for a specific URL |
| `VNC_PASSWORD` | (none) | Password-protect the VNC/noVNC viewer |

### Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 5800 | HTTP | noVNC web viewer |
| 5900 | VNC | Native VNC client access |
| 9222 | WebSocket | Chrome DevTools Protocol |

### Volumes

| Container Path | Purpose |
|---------------|---------|
| `/config` | Chromium profile, cookies, sessions, downloads, logs |

### Resource Limits

The default `docker-compose.yml` sets `memory: 1g` and `cpus: 1.0` to prevent the browser from starving other services. Adjust based on your needs:

| State | RAM Usage |
|-------|-----------|
| Idle (browser open, no tabs) | ~250 MB |
| Active (1 tab, typical page) | ~500 MB |
| Heavy (complex SPA, multiple tabs) | 1-2 GB |

## How It Works

```
jlesage/chromium base image
  Chromium 144 + Xvfb + TigerVNC + noVNC + nginx
  + --remote-debugging-port=9222 (added by this image)
  + agent-browser 0.21.0 (Rust CLI, installed via npm)
```

- **jlesage/chromium** handles the display stack: Xvfb creates a virtual screen, TigerVNC serves it, noVNC makes it accessible via web browser, nginx fronts it all on port 5800.
- **agent-browser** connects to Chrome via CDP (port 9222) and provides the command interface. Its snapshot/refs system means the AI agent sees `@e1: button "Submit"` instead of thousands of DOM nodes -- 90% fewer tokens than Playwright MCP.
- The two don't know about each other. Chrome just runs with an extra flag, and agent-browser connects to it like any other CDP target.

## Building

```bash
docker compose build
```

Pin a specific agent-browser version:

```bash
docker compose build --build-arg AGENT_BROWSER_VERSION=0.21.0
```

The image is ~400 MB compressed (360 MB base + ~40 MB Node.js + agent-browser).

## Security Notes

- **CDP port 9222** grants full browser control to anyone who can reach it. Only expose on trusted networks or behind a firewall.
- **noVNC port 5800** shows everything in the browser. Set `VNC_PASSWORD` if the viewer is network-accessible.
- **Session data** (cookies, localStorage) persists in the `/config` volume. Treat it like any credential store.
- The container runs Chromium with `--no-sandbox` if the Docker seccomp profile doesn't allow `unshare`. For full sandbox support, use `--cap-add=SYS_ADMIN` (included in the default compose file).

## Tested On

- Unraid 7.2.3 (Docker 27.x)
- Chromium 144.0.7559.132
- agent-browser 0.21.0

## Credits

- [jlesage/docker-chromium](https://github.com/jlesage/docker-chromium) -- the excellent base image that makes GUI-in-Docker painless
- [vercel-labs/agent-browser](https://github.com/vercel-labs/agent-browser) -- the token-efficient browser CLI for AI agents
- Built with [Claude Code](https://claude.ai/code)

## License

GPL-3.0 -- see [LICENSE](LICENSE)
