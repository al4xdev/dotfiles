---
name: portmaster
description: Guide and instructions for managing PortMaster on retro consoles (ArkOS, EmuELEC, etc.), including file paths, JSON metadata, and manually downloading/installing ports.
---

# PortMaster Customization Skill

This skill contains documentation and guidelines for managing PortMaster on retro handheld systems (like ArkOS, EmuELEC, JelOS, etc.).

## 1. Directory Structure and Paths
*   **PortMaster Installation Folder:** `/opt/system/Tools/PortMaster/` or `/roms/tools/PortMaster/`
*   **Ports Root Folder (ROMs):** `/roms/ports/` (this is where launcher `.sh` files and game directories reside)
*   **Runtimes Folder:** `/opt/system/Tools/PortMaster/runtimes/`

## 2. Configuration and Metadata Files
PortMaster config files are located inside `/opt/system/Tools/PortMaster/config/` (or `/roms/tools/PortMaster/config/`):
*   `ports_info.json`: Maps individual launcher scripts and directory names to their respective `.zip` package name.
*   `020_portmaster.source.json`: Contains the primary database of available ports. Under `data.data`, it maps each port `.zip` to its details:
    *   `name`: File name (e.g., `moonlight.zip`)
    *   `url`: Direct GitHub releases download link
    *   `md5`: Checksum
    *   `size`: File size
    *   `attr`: Game metadata (title, porter, description, genres, runtimes, arch, etc.)
*   `021_portmaster.multiverse.source.json`: Additional database containing community/multiverse ports.
*   `runtimes.json`: Maps required runtimes (like Mono, Godot, etc.) to their download locations.

## 3. Manual Port Installation Workflow
If you need to install a port manually from the command line:

1.  **Retrieve Download URL:**
    Search `020_portmaster.source.json` (or multiverse source) for the desired game using Python or grep:
    ```python
    import json
    with open('/opt/system/Tools/PortMaster/config/020_portmaster.source.json') as f:
        d = json.load(f)
    port_data = d['data']['data']['game_filename.zip']
    print(port_data['url'])
    ```
2.  **Download and Extract:**
    Download the zip file directly to `/tmp/`, extract it to `/roms/ports/`, and then delete the zip:
    ```bash
    wget -O /tmp/port.zip <URL_FROM_JSON>
    unzip -o /tmp/port.zip -d /roms/ports/
    rm /tmp/port.zip
    ```
3.  **Add Game Data Files (If Required):**
    Some ports (e.g., commercial games or fan demakes) only contain the engine/wrapper. You must manually copy the original game assets (e.g., `.exe`, `.pck`, folder contents) into the port's subfolder (typically `gamedata/` or the port's root directory):
    *   *Example (Mega Man X8 16-Bit):* Extract game files into `/roms/ports/megamanx816-bit/gamedata/`.
