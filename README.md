# gemini-proxy

Use Gemini from coding agents such as [opencode](https://opencode.ai) **without a Gemini API key**, through the Gemini web app you can already use with your Google Workspace account.

gemini-proxy runs on your own machine and exposes an **OpenAI-compatible** and a **Gemini-compatible** API on `http://localhost:8081`. Behind the scenes it talks to `gemini.google.com` with the session of a browser in which you signed in once.

> [!IMPORTANT]
> This is an unofficial tool built on reverse-engineered, undocumented web endpoints. It can break whenever Google changes the Gemini web app, it is slower than the real API, and tool calling is emulated (see [Limitations](#limitations)). Check that using it complies with your company's policies before relying on it.

## How it works

```
 opencode / any OpenAI or Gemini client
                │  http://localhost:8081  (API key from your .env)
                ▼
 ┌──────────── proxy ─────────────┐      ┌──────── browser ────────┐
 │ OpenAI + Gemini compatible API │      │ Chromium, signed in to  │◄── you, once, at
 │ (gemini-web2api, pinned)       │      │ Gemini with your account│    http://localhost:3000
 └───────────────┬────────────────┘      └───────────┬─────────────┘
                 │ reads                             │ DevTools protocol
                 ▼                                   │
          session volume  ◄────── session-sync ──────┘
   (cookies, XSRF token, build id)   refreshes every 10 min
                 │
                 ▼
        https://gemini.google.com  (the same endpoint the web app uses)
```

Three containers, started together by Docker Compose:

| Service | What it does |
|---|---|
| `browser` | A Chromium you reach from your own browser at http://localhost:3000. You sign in to Gemini there once; the session is kept in a Docker volume. |
| `session-sync` | Every 10 minutes it reloads Gemini in a background tab and exports the cookies and page tokens the web app needs. Token rotation is handled for you. |
| `proxy` | [gemini-web2api](https://github.com/Sophomoresty/gemini-web2api) (MIT, pinned to a reviewed commit) plus a small launcher that feeds it the live session and makes tool calling more reliable for agents. |

Everything listens on `127.0.0.1` only: nothing is reachable from other machines.

## Requirements

- Docker with Docker Compose v2 (`docker compose`). Docker Desktop, Docker Engine on Linux and **Rancher Desktop** (with the `dockerd (moby)` engine) all work. See **[docs/install-docker.md](docs/install-docker.md)** if you need to install one.
- About 5 GB of disk space (the browser image is large) and 2 GB of free RAM.
- A Google account with access to Gemini at https://gemini.google.com.

## Quick start

```bash
git clone <this repository> gemini-proxy
cd gemini-proxy
cp .env.example .env
```

Edit `.env` and set `PROXY_API_KEY` to a random value of your choice (for example the output of `openssl rand -hex 16`). On Linux, also set `PUID`/`PGID` to the output of `id -u` / `id -g`.

Start everything (the first run downloads and builds the images, which takes a few minutes):

```bash
docker compose up -d
```

Then sign in, **once**:

1. Open **http://localhost:3000** in your normal browser. You see a Chromium window already on Gemini.
2. Sign in with your work Google account (SSO included) and wait until the Gemini chat page is loaded.
3. Within about 10 seconds the proxy picks up the session:

   ```bash
   docker compose logs session-sync
   # session-sync-1  | session exported (account index: default, build: boq_...)
   ```

Check that the API answers (replace `YOUR_KEY` with your `PROXY_API_KEY`):

```bash
curl http://localhost:8081/v1/chat/completions \
  -H "Authorization: Bearer YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"gemini-3.6-flash","messages":[{"role":"user","content":"Say hello"}]}'
```

The containers restart with Docker, and the session survives restarts. Sign in again at http://localhost:3000 only if Google logs you out.

## Using it with opencode

### Option A: opencode installed on your machine (recommended)

Install opencode ([instructions](https://opencode.ai/docs/)), then add the provider to your opencode configuration: `~/.config/opencode/opencode.json` on Linux and macOS, `%USERPROFILE%\.config\opencode\opencode.json` on Windows. If the file already exists, merge the `provider` block into it.

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "gemini-proxy": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Gemini (web proxy)",
      "options": {
        "baseURL": "http://localhost:8081/v1",
        "apiKey": "{env:GEMINI_PROXY_API_KEY}"
      },
      "models": {
        "gemini-3.6-flash": { "name": "Gemini 3.6 Flash (web)" }
      }
    }
  },
  "model": "gemini-proxy/gemini-3.6-flash"
}
```

Export the key in your shell profile, then run `opencode` in any project:

```bash
export GEMINI_PROXY_API_KEY=YOUR_KEY            # bash / zsh
$env:GEMINI_PROXY_API_KEY = "YOUR_KEY"          # PowerShell
```

This is the best option for real work: opencode runs commands (tests, builds, git) with the tools already installed on your machine.

### Option B: opencode in a container, to try it out

No installation needed. From the folder you want opencode to work on:

```bash
/path/to/gemini-proxy/scripts/opencode.sh                       # interactive
/path/to/gemini-proxy/scripts/opencode.sh run "explain this repo" # one-shot
```

On Windows (PowerShell): `\path\to\gemini-proxy\scripts\opencode.ps1`.

The container sees **only the current folder** (mounted at `/work`), and the commands opencode runs execute inside the container, which only has `git`, `python3` and `ripgrep`. Your project's toolchain (node, java, go, ...) is not available there. Sessions are not kept between runs. Use `REBUILD=1` to rebuild the image after an update.

## Other clients

Any client that can use an OpenAI-compatible endpoint works with base URL `http://localhost:8081/v1` and your key as API key.

The proxy also implements the Gemini API (`/v1beta/models/...:generateContent` and `:streamGenerateContent`) and the OpenAI Responses API (`/v1/responses`). For example, [Gemini CLI](https://github.com/google-gemini/gemini-cli):

```bash
export GEMINI_API_KEY=YOUR_KEY
export GOOGLE_GEMINI_BASE_URL=http://localhost:8081
gemini
```

### Models

`GET /v1/models` lists the names the proxy accepts. `gemini-3.6-flash` is the tested default. The others (`gemini-3.7-flash`, `gemini-3.1-pro`, `gemini-3.5-flash-thinking`, `gemini-flash-lite`, `gemini-auto`) select the corresponding mode in the web app. Which model actually answers depends on what your account is entitled to, and the web app may silently fall back to Flash. Unknown model names fall back to `DEFAULT_MODEL`.

## Configuration

All settings live in `.env` (see [`.env.example`](.env.example) for the full list):

| Variable | Default | Meaning |
|---|---|---|
| `PROXY_API_KEY` | *(required)* | Key clients must send (`Authorization: Bearer ...` or `x-api-key`). |
| `PROXY_PORT` / `BROWSER_PORT` | `8081` / `3000` | Local ports. |
| `DEFAULT_MODEL` | `gemini-3.6-flash` | Used for unknown model names. |
| `TEMPORARY_CHATS` | `true` | Send conversations as Gemini temporary chats, so they don't appear in your Gemini history. |
| `TOOL_REMINDER` | `true` | Append a reminder of the tool-call format to agent prompts (see Limitations). |
| `SYNC_INTERVAL_SEC` | `600` | How often the session is refreshed. |
| `GEMINI_AUTH_USER` | *(empty)* | If several Google accounts are signed in to the proxy browser: the `N` of `gemini.google.com/u/N/app` to use. |

After changing `.env`, apply it with `docker compose up -d`.

## Limitations

- **Tool calling is emulated.** The web app has no function calling, so the proxy describes the tools in the prompt and parses the model's reply. It works most of the time, but sometimes the model describes the next step ("Let me read the file") instead of doing it, or asks you for the file's contents. That ends the agent's turn: just answer *"go on"* or *"use your tools"*. In our tests on small coding tasks, opencode completed the task on the first try in roughly 7–9 runs out of 10.
- **Every request is a fresh conversation.** The whole history is sent each time, so very long agent sessions mean very large prompts. Start new sessions for new tasks.
- **Slower than the API.** Expect 3–10 seconds per step.
- **Rate limits.** Google may throttle or challenge heavy, automated use of the web app.
- **It can break.** Changes to the Gemini web app can break the proxy until the pinned upstream is updated.

## Security and privacy

- Your **Google session lives in two Docker volumes**: `gemini-proxy_profile` (the browser profile) and `gemini-proxy_session` (cookies and tokens). Anyone who can read them can act as you on Google. Don't copy them around, and remove them when you stop using the proxy:

  ```bash
  docker compose down -v
  ```

- All ports are bound to `127.0.0.1`. The browser UI at port 3000 has no password, so **do not** change the bindings to `0.0.0.0` or expose them on a network.
- `.env` holds your proxy key and is git-ignored. Never commit it.
- What you send through the proxy goes to Gemini exactly as if you had typed it in the web app, under your account and your organization's Workspace terms.
- The upstream proxy code is fetched at a pinned commit that was reviewed: it only contacts Google domains. Review the diff before bumping `WEB2API_COMMIT` in [`proxy/Dockerfile`](proxy/Dockerfile).

## Troubleshooting

| Symptom | Fix |
|---|---|
| `session-sync` keeps logging `waiting: not signed in` | Open http://localhost:3000 and sign in. If you are, reload the Gemini page there. |
| API returns `upstream error: HTTP Error 400` | The session is stale or missing. Check `docker compose logs session-sync`, sign in again if needed, or force a refresh with `docker compose restart session-sync`. |
| API returns `401` | The key sent by the client doesn't match `PROXY_API_KEY` in `.env`. |
| Empty answers (`content: null`) | Google rejected the request. Wait a few minutes (rate limit), or check that you can still chat at http://localhost:3000. |
| Image build fails with `Temporary failure in name resolution` or `EAI_AGAIN` | Builds on your machine can't resolve DNS. Create `docker-compose.override.yml` (git-ignored) with the content below, and for the opencode container run `BUILD_NETWORK=host scripts/opencode.sh`. |
| Port already in use | Change `PROXY_PORT` / `BROWSER_PORT` in `.env` (and the `baseURL` in your opencode config). |
| The browser page at :3000 is blank on Apple Silicon or is slow | Give Docker / Rancher Desktop more memory (4 GB or more). |

`docker-compose.override.yml` for the DNS problem:

```yaml
services:
  session-sync:
    build:
      network: host
  proxy:
    build:
      network: host
```

Useful commands:

```bash
docker compose ps                  # are the three services running?
docker compose logs -f proxy       # every API request
docker compose logs -f session-sync
docker compose down                # stop (the session is kept)
docker compose down -v             # stop and delete the session
docker compose build --pull && docker compose up -d   # update images
```

## Credits

The Gemini web protocol implementation is [gemini-web2api](https://github.com/Sophomoresty/gemini-web2api) by Sophomoresty (MIT license), used unmodified. The browser is [linuxserver/chromium](https://docs.linuxserver.io/images/docker-chromium/).
