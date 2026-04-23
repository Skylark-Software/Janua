# Your First Remote Desktop Connection

This walks you through connecting to your first machine after installing Janua. It assumes you've already got Janua running (via the [Proxmox installer](../proxmox/README.md) or [Docker](SETUP.md)) and you can reach the web UI at `http://<your-janua-ip>:8085/janua`.

## 1. Log in for the first time

Open the Janua web UI. You'll see the Guacamole login screen.

- **Username:** `admin`
- **Password:** `admin`

**Change the password immediately.** After logging in:

1. Click your username in the top right → **Preferences**
2. Scroll to **Change Password**
3. Set a new password and save

## 2. Turn on RDP on the machine you want to access

Before Janua can connect to a remote machine, that machine needs to be accepting RDP connections. Pick the one that matches your target:

- **GNOME (Fedora 42, Ubuntu 25.04+)** — `grdctl rdp enable` + set credentials + generate TLS cert. See the [full GNOME setup in SETUP.md](SETUP.md#gnome-remote-desktop-fedora-42-ubuntu-2504).
- **KDE Plasma (Fedora 42+)** — System Settings → Remote Desktop → Allow remote connections → set password.
- **Windows 10 / 11** — Settings → System → Remote Desktop → toggle on. Note the PC name or IP.
- **Linux with xrdp** — `sudo apt install xrdp` (or `dnf install xrdp`), then `sudo systemctl enable --now xrdp`.

Note the target machine's **IP address** or **hostname**, the **username** to log in as, and that user's **password**. You'll need all three in the next step.

## 3. Add the connection in Janua

Back in the Janua web UI:

1. Click your username in the top right → **Settings**
2. Click the **Connections** tab
3. Click **New Connection** (top right)
4. Fill in:

   | Field | What to put |
   |-------|-------------|
   | **Name** | Anything you'll recognise — e.g. `My Desktop` |
   | **Protocol** | **RDP** |
   | **Hostname** (under Network) | The target's IP or hostname |
   | **Port** | `3389` (default — leave as-is) |
   | **Username** (under Authentication) | The username on the target machine |
   | **Password** | That user's password on the target |
   | **Ignore server certificate** (under Security) | ✅ Check this (targets use self-signed certs by default) |
   | **Enable audio** (under Device Redirection) | ✅ Check this if you want sound |

5. Scroll to the bottom and click **Save**

## 4. Connect

1. Click **Home** in the top nav (or click your username → **Home**)
2. Your connection name is listed — click it
3. The remote desktop appears in your browser

That's it. You can close the tab to disconnect; clicking the connection again reconnects.

## Tips

- **To switch between connections quickly**, press `Ctrl+Alt+Shift` while connected — that opens Janua's side menu over the session.
- **File transfer**: most setups have a shared `drive` folder. Drag-and-drop into the session to upload.
- **Audio not working?** Make sure the target machine's screen is unlocked (many RDP servers block audio when the session is locked).
- **Connection fails immediately?** Double-check the target's firewall allows port 3389 and that RDP is actually running. See [Troubleshooting in the README](../README.md#troubleshooting).

## Adding more connections

Repeat step 3 for each machine you want to access. Janua keeps them all on one home page and you switch between them with a click.

## Inviting other users

You can create additional Janua user accounts from **Settings → Users → New User**. Each user sees only the connections you share with them — set the **Connections** tab on the user's profile to grant access.
