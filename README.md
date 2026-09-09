# omarchy-gaming

One-keybind gaming mode for [Omarchy](https://omarchy.org/) Linux. Press
**Super + Ctrl + G** to toggle between a development-focused desktop and a
low-latency competitive gaming setup — then press it again to switch back.

## What It Does

**When enabled (gaming mode on):**

- Disables compositor animations, blur, shadows, and window rounding
- Enables direct scanout (bypasses compositor frame buffering in fullscreen)
- Suppresses desktop notifications (Do Not Disturb)
- Inhibits idle lock and screensaver
- Sets CPU governor to `performance`
- Applies CS2-specific immediate tearing for sub-frame input response
- Creates a `gaming` workspace rule with zero gaps/borders

**When disabled (gaming mode off):**

- Restores all standard desktop behavior
- Re-enables notifications, idle, screensaver
- Returns power profile to `power-saver`

## Quick Start

```bash
git clone <this-repo> ~/Projects/omarchy-gaming
cd ~/Projects/omarchy-gaming
chmod +x install.sh
./install.sh
```

The installer will:

1. Detect your CPU and pick the right CachyOS kernel repo tier
2. Install the toggle script, Hyprland overrides, and GameMode config
3. Add the `Super + Ctrl + G` keybinding
4. Install `gamemode` if missing
5. Optionally set up CachyOS repos and kernel

### Options

```bash
./install.sh                # Full interactive install
./install.sh --no-cachyos   # Skip CachyOS kernel/repo setup
./install.sh --uninstall    # Remove everything
```

## CPU Tier Auto-Detection

The installer detects your CPU and selects the optimal CachyOS repository tier:

| CPU | Tier | Packages compiled with |
|-----|------|----------------------|
| AMD Zen 4 / Zen 5 | `znver4` | AVX-512, Zen 4 µarch flags |
| AMD Zen 3 | `znver3` | AVX2, Zen 3 µarch flags |
| Intel (AVX-512) | `x86-64-v4` | AVX-512 instruction set |
| Intel/AMD (AVX2) | `x86-64-v3` | AVX2 instruction set |
| Older CPUs | `generic` | Baseline x86-64 |

## Steam Launch Options

```
gamemoderun %command% -nojoy +exec autoexec.cfg
```

- `gamemoderun` — engages Feral GameMode (process priority + CPU governor)
- `-nojoy` — disables joystick thread polling on Linux
- `+exec autoexec.cfg` — loads user binds/settings

## Files Installed

| File | Location |
|------|----------|
| Toggle script | `~/.local/bin/omarchy-gaming-toggle` |
| Hyprland overrides | `~/.local/state/omarchy/toggles/hypr/gaming.lua` |
| GameMode config | `~/.config/gamemode.ini` |
| Shader cache env | `~/.config/environment.d/gaming.conf` |
| Keybinding | Appended to `~/.config/hypr/bindings.lua` |

## Pre-Flight Checks

Before gaming, make sure:

1. **Booted into CachyOS kernel** — `uname -r` should contain `cachyos`
2. **Plugged into AC power** — the toggle warns on battery
3. **Steam is running** with the launch options above

## Modifying

- **Keybinding:** edit `~/.config/hypr/bindings.lua`
- **Toggle behavior:** edit `~/.local/bin/omarchy-gaming-toggle`
- **Hyprland rules:** edit `~/.local/state/omarchy/toggles/hypr/gaming.lua`
- **GameMode tuning:** edit `~/.config/gamemode.ini`
- **Shader cache cap:** edit `~/.config/environment.d/gaming.conf`
- **Emergency reset:** remove `~/.local/state/omarchy/toggles/gaming` and run `hyprctl reload`

## Uninstalling

```bash
./install.sh --uninstall
```

This removes all installed files and the keybinding. CachyOS repos/kernel are
left in place (remove manually from `/etc/pacman.conf` if desired).
