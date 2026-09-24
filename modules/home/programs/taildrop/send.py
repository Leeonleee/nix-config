"""Dolphin Taildrop action: discover eligible peers and send selected local files."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def dialog(*args):
    return subprocess.run(
        ["kdialog", "--title", "Send with Taildrop", *args],
        text=True, capture_output=True,
    )


def discover_devices(status, targets, nicknames):
    # `file cp --targets` is the CLI's authoritative Taildrop eligibility list.
    eligible = {line.split()[0] for line in targets.splitlines() if line.split()}
    devices = []
    for peer in (status.get("Peer") or {}).values():
        addresses = peer.get("TailscaleIPs") or []
        address = next((ip for ip in addresses if ip in eligible), None)
        if not address or not peer.get("Online"):
            continue
        dns = peer.get("DNSName", "").rstrip(".")
        hostname = peer.get("HostName", "")
        keys = [*addresses, dns, dns.split(".")[0], hostname]
        nickname = next((nicknames[key] for key in keys if key in nicknames), None)
        name = nickname or dns.split(".")[0] or hostname or address
        label = f"{name} — {peer.get('OS') or 'unknown OS'} — {address}"
        devices.append((nickname is None, name.casefold(), address, label))
    return sorted(devices)


def main():
    nicknames = json.loads(Path(sys.argv[1]).read_text())
    # Absolute paths also prevent filenames beginning with '-' becoming CLI flags.
    files = [os.path.abspath(path) for path in sys.argv[2:]]
    if not files:
        return
    if any(not Path(path).is_file() for path in files):
        dialog("--error", "Taildrop sends files only. Compress folders into an archive first.")
        return

    status = json.loads(subprocess.run(
        ["tailscale", "status", "--json"], check=True,
        capture_output=True, text=True, timeout=20,
    ).stdout)
    if status.get("BackendState") != "Running":
        dialog("--error", "Tailscale is not connected. Connect it and try again.")
        return
    targets = subprocess.run(
        ["tailscale", "file", "cp", "--targets"], check=True,
        capture_output=True, text=True, timeout=20,
    ).stdout
    devices = discover_devices(status, targets, nicknames)
    if not devices:
        dialog("--msgbox", "No online Taildrop devices are available.\n"
               "Make sure the recipient is connected to Tailscale and supports Taildrop.")
        return
    choices = [value for _, _, address, label in devices for value in (address, label)]
    selection = dialog("--menu", f"Send {len(files)} file(s) to:", *choices)
    if selection.returncode != 0:
        return
    address = selection.stdout.strip()
    if address not in {device[2] for device in devices}:
        raise ValueError("The selected device is no longer valid.")

    dialog("--passivepopup", "Sending files with Taildrop…", "5")
    # No transfer timeout: large files can take time. Spool output instead of
    # retaining unbounded CLI progress/error output in memory.
    with tempfile.TemporaryFile(mode="w+") as output:
        result = subprocess.run(
            ["tailscale", "file", "cp", "--update-interval=0", *files, f"{address}:"],
            stdout=output, stderr=output, text=True,
        )
        if result.returncode:
            output.seek(0)
            dialog("--error", "Taildrop transfer failed (some files may have arrived):\n\n"
                   + output.read(6000))
            return
    dialog("--passivepopup", f"Sent {len(files)} file(s) with Taildrop.", "8")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        detail = error.stderr if isinstance(error, subprocess.CalledProcessError) else str(error)
        dialog("--error", f"Could not send with Taildrop:\n\n{detail}")
