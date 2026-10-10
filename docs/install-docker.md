# Installing a container runtime

gemini-proxy needs the `docker` command and Docker Compose v2 (`docker compose`, with a space). Any of these provides both:

| Option | Platforms | Notes |
|---|---|---|
| [Rancher Desktop](#rancher-desktop) | macOS, Windows, Linux | Free and open source, with a GUI. |
| [Docker Engine](#docker-engine-linux) | Linux | Free, no GUI. The simplest choice on Linux. |
| [Docker Desktop](#docker-desktop) | macOS, Windows, Linux | Free for personal use; larger companies need a paid subscription. |

If one of them is already installed, skip to [Check the installation](#check-the-installation).

## Rancher Desktop

Official docs: https://docs.rancherdesktop.io/getting-started/installation

### 1. Install

**macOS** (Intel or Apple Silicon): download the `.dmg` for your chip from https://rancherdesktop.io and drag *Rancher Desktop* into Applications, or use Homebrew:

```bash
brew install --cask rancher
```

**Windows 10/11**: Rancher Desktop runs on WSL 2. If you don't have it yet, open PowerShell **as Administrator**, run `wsl --install`, and reboot. Then install Rancher Desktop with the `.msi` installer from https://rancherdesktop.io, or:

```powershell
winget install --id SUSE.RancherDesktop -e
```

**Linux**: follow the official instructions for your distribution (`.deb` / `.rpm` repository or AppImage). Your user needs access to `/dev/kvm`; on most distributions:

```bash
sudo usermod -aG kvm "$USER"   # then log out and back in
```

### 2. Configure

Start Rancher Desktop. On first launch, or later in **Preferences**:

1. **Container Engine → `dockerd (moby)`.** This is required. With `containerd` you get `nerdctl` instead of `docker`, and gemini-proxy's scripts and Compose file are not tested with it.
2. **Kubernetes → uncheck "Enable Kubernetes".** It's not needed and saves memory and CPU.
3. **Application → Environment → PATH configuration: Automatic**, so `docker` is on your `PATH`. Open a **new** terminal afterwards.
4. **Virtual Machine → Memory: 4 GB or more** (macOS and Linux). On Windows, memory is managed by WSL 2 and is usually enough.

Wait until the status bar at the bottom of the window says the engine is running.

## Docker Engine (Linux)

Official docs, with per-distribution instructions: https://docs.docker.com/engine/install/

The quickest path on Ubuntu, Debian, Fedora and similar is Docker's convenience script. It installs the engine and the Compose plugin:

```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

Let your user run `docker` without `sudo`:

```bash
sudo usermod -aG docker "$USER"   # then log out and back in
```

If you installed Docker from your distribution's packages instead and `docker compose` is missing, install the Compose plugin (`docker-compose-plugin` on Debian/Ubuntu/Fedora when using Docker's repository): https://docs.docker.com/compose/install/linux/

> The old standalone `docker-compose` (with a hyphen, v1) is not supported. You need `docker compose` (v2).

## Docker Desktop

Official docs: https://docs.docker.com/desktop/ (macOS, Windows, Linux). Docker Compose is included. On Windows, enable the WSL 2 backend when asked.

Docker Desktop is free only for personal use, education, and small businesses. Larger companies need a paid subscription. Rancher Desktop is a free alternative.

## Check the installation

In a new terminal:

```bash
docker version            # shows both Client and Server
docker compose version    # Docker Compose version v2.x or newer
docker run --rm hello-world
```

If `docker version` shows the client but errors on the server ("Cannot connect to the Docker daemon"):

- **Rancher Desktop / Docker Desktop:** make sure the app is running and has finished starting.
- **Linux Docker Engine:** `sudo systemctl enable --now docker`, and check that you logged out and back in after joining the `docker` group.

### Behind a corporate proxy or TLS inspection

If `docker compose up` fails while downloading images or packages, with timeouts or certificate errors, your network probably requires a proxy or re-signs TLS traffic.

- Rancher Desktop and Docker Desktop: set the proxy in the app's network/proxy settings.
- Docker Engine: see https://docs.docker.com/engine/daemon/proxy/

Your network administrator can give you the proxy address and, if needed, the root certificate to trust.

Now go back to the [Quick start](../README.md#quick-start).
