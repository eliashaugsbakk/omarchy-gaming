> [!NOTE]
> This project was built entirely through AI-assisted prompting (vibe coding).
> The code, configuration, and documentation were generated and iterated on
> through conversational AI pair programming. Review before running on your
> system.

# omarchy-gaming

One-keybind gaming mode for [Omarchy](https://omarchy.org/) Linux. Press
**Super + Ctrl + G** to toggle between a development-focused desktop and a
low-latency competitive gaming setup — then press it again to switch back.

This repo is the single source of truth for the entire gaming mode
implementation. It contains every file, explains every design decision, and
provides an installer that can replicate the full setup on a fresh Omarchy
system or cleanly revert it.

---

## Quick Start

```bash
git clone <this-repo> ~/Projects/omarchy-gaming
cd ~/Projects/omarchy-gaming
chmod +x install.sh
./install.sh
```

### Installer Options

```bash
./install.sh                # Full interactive install
./install.sh --no-cachyos   # Skip CachyOS kernel/repo setup
./install.sh --uninstall    # Remove everything this script installed
```

---

## Architecture Overview

The gaming mode is built in three layers. Each layer is independent — you
can use any combination.

### Layer 1 — Omarchy Integration

These components use Omarchy's shell, toggle architecture, and Lua-based
Hyprland config. They work on any Omarchy install.

| File | Installed to | Purpose |
|------|-------------|---------|
| `omarchy-gaming-toggle` | `~/.local/bin/omarchy-gaming-toggle` | Main toggle script |
| `gaming.lua` | `~/.local/state/omarchy/toggles/hypr/gaming.lua` | Hyprland compositor overrides |
| *(keybinding)* | Appended to `~/.config/hypr/bindings.lua` | `Super + Ctrl + G` trigger |

### Layer 2 — Linux Gaming General

Standard Linux gaming optimizations. Work on any distro with Vulkan.

| File | Installed to | Purpose |
|------|-------------|---------|
| `gamemode.ini` | `~/.config/gamemode.ini` | Feral GameMode process scheduling |
| `gaming.conf` | `~/.config/environment.d/gaming.conf` | Mesa shader cache cap |

### Layer 3 — CachyOS Kernel & Repos

Performance kernel with architecture-specific package compilation. The
installer auto-detects your CPU (see [CPU Tier Detection](#cpu-tier-auto-detection)).
This layer is optional (`--no-cachyos` to skip).

| What | Details |
|------|---------|
| Kernel | `linux-cachyos` — EEVDF + BORE (Burst-Oriented Response Enhancer) scheduler |
| Repos | Architecture-optimized Mesa, Vulkan, and system packages |
| Config | CachyOS repos added to `/etc/pacman.conf` before `[core]` |

---

## What The Toggle Does

### State: Gaming Mode ON

The toggle script (`omarchy-gaming-toggle`) runs these steps in order:

1. **Create flag file:** `~/.local/state/omarchy/toggles/gaming`
2. **Reload Hyprland:** `hyprctl reload` — applies `gaming.lua` overrides
3. **Silence notifications:** `omarchy-shell notifications setDnd on`
4. **Inhibit idle/sleep:** `omarchy toggle idle stay-awake`
5. **Disable screensaver:** `omarchy-toggle screensaver-off off`
6. **Set performance governor:** `omarchy-powerprofiles-set autodetect performance`
7. **Send confirmation notification** (low urgency)

### State: Gaming Mode OFF

1. **Remove flag file:** `~/.local/state/omarchy/toggles/gaming`
2. **Reload Hyprland:** restores standard desktop styling
3. **Restore notifications:** `omarchy-shell notifications setDnd off`
4. **Re-enable idle/screensaver:** `omarchy toggle idle allow-idle` / `omarchy-toggle screensaver-off on`
5. **Restore power profile:** `omarchy-powerprofiles-set autodetect power-saver`
6. **Send confirmation notification**

### Pre-Flight Safety Checks

Before enabling, the script checks two conditions:

1. **AC power** — queries UPower via `busctl ... OnBattery`
2. **CachyOS kernel** — checks `uname -r` for `cachyos`

If either check fails, a **critical desktop notification** warns the user.
Clicking the notification re-runs the script with `--force` to override.
This protects battery life and ensures the low-latency scheduler is present.

---

## Hyprland Effects (`gaming.lua`)

The Lua override is conditionally applied — it reads the gaming flag file at
Hyprland reload time and exits early if the flag is absent.

| Setting | Value | Why |
|---------|-------|-----|
| `render.direct_scanout` | `1` | Bypasses compositor frame buffering in fullscreen for minimum presentation latency |
| `animations.enabled` | `false` | Eliminates animation overhead |
| `decoration.shadow.enabled` | `false` | Reduces GPU draw calls |
| `decoration.blur.enabled` | `false` | Frees GPU time from Kawase blur passes |
| `decoration.rounding` | `0` | Removes rounded corner anti-aliasing |

### Workspace Rule (`name:gaming`)

```
gaps_in=0, gaps_out=0, border_size=0, decorate=false, no_rounding=true, no_shadow=true
```

Gives fullscreen-like real estate without entering true fullscreen.

### Window Rule (CS2)

```
match: class = "^cs2$"  →  immediate = true
```

Enables immediate tearing for sub-frame input response. The frame is
presented as soon as it is ready rather than waiting for the next vblank.

---

## GameMode Config (`gamemode.ini`)

[Feral GameMode](https://github.com/FeralInteractive/gamemode) is activated
per-game via `gamemoderun` in Steam launch options.

```ini
[general]
renice=10
ioprio=0

[cpu]
governor=performance
```

| Setting | Value | Effect |
|---------|-------|--------|
| `renice` | `10` | Elevates game process priority above standard desktop apps |
| `ioprio` | `0` | Real-time I/O scheduling — prevents hitches during asset/map streaming |
| `governor` | `performance` | Pins CPU frequency scaling at maximum clocks |

---

## Mesa Shader Cache (`gaming.conf`)

```bash
MESA_SHADER_CACHE_MAX_SIZE=10G
```

Overrides Mesa's default 1 GB cap. Prevents aggressive shader cache eviction
that causes runtime compilation micro-stutters during smokes, flashes, and
particle effects. Applied system-wide via `environment.d`.

---

## Steam Launch Options

```
gamemoderun %command% -nojoy +exec autoexec.cfg
```

| Flag | Purpose |
|------|---------|
| `gamemoderun` | Engages `gamemoded` priority and governor hooks |
| `-nojoy` | Disables joystick thread polling on Linux |
| `+exec autoexec.cfg` | Loads user binds/settings |

> Legacy flags `-high` and `-vulkan` are redundant on native Linux CS2 and
> have been omitted.

---

## CPU Tier Auto-Detection

The installer reads `/proc/cpuinfo` to determine the optimal CachyOS
repository tier:

| CPU | Detected Tier | Packages compiled with |
|-----|---------------|----------------------|
| AMD Zen 4 / Zen 5 (family 25 model ≥ 96, or family 26) | `znver4` | AVX-512, Zen 4 µarch flags |
| AMD Zen 3 (family 25 model < 96) | `znver3` | AVX2, Zen 3 µarch flags |
| Intel/AMD with AVX-512 | `x86-64-v4` | AVX-512 instruction set |
| Intel/AMD with AVX2 | `x86-64-v3` | AVX2 instruction set |
| Older CPUs | `generic` | Baseline x86-64 |

The tier determines which `[cachyos-*]` repos and mirrorlist are added to
`/etc/pacman.conf`. Architecture-specific repos are placed before `[core]`
so optimized packages take priority.

---

## Hardware Reference (Origin System)

This setup was developed and tested on the following hardware. The
configuration is portable to other systems, but these specs explain certain
design choices (e.g., APU power sharing).

| Component | Spec |
|-----------|------|
| **CPU** | AMD Ryzen 7 PRO 250 (Zen 4, 8 cores / 16 threads) |
| **GPU** | Integrated AMD Radeon 780M (RDNA3, HawkPoint1) |
| **RAM** | 30 GB LPDDR5X with ZRAM swap (`zstd`, 30 GB) |
| **Display** | 1920×1200 @ 60.003 Hz (`eDP-1`) |
| **CachyOS tier** | `znver4` (AVX-512, Zen 4 µarch) |

### APU Power Sharing Note

Because CPU and GPU share the same thermal and power package on this
integrated APU, in-game particle detail and ambient occlusion should remain
on **Low** or **Disabled** to leave maximum power budget for GPU core clocks.
This applies to any system with a shared CPU/GPU power domain (AMD APUs,
Intel integrated graphics).

---

## Modifying

| What | File to edit |
|------|-------------|
| Keybinding | `~/.config/hypr/bindings.lua` |
| Toggle behavior (commands, safety checks) | `~/.local/bin/omarchy-gaming-toggle` |
| Hyprland overrides (compositor, window rules) | `~/.local/state/omarchy/toggles/hypr/gaming.lua` |
| GameMode scheduling tuning | `~/.config/gamemode.ini` |
| Shader cache cap | `~/.config/environment.d/gaming.conf` |
| CachyOS repos | `/etc/pacman.conf` (requires sudo) |

### Important Omarchy Command Notes

The toggle script uses specific Omarchy commands. Be aware of the distinction:

| Command | What it does |
|---------|-------------|
| `omarchy-toggle <flag> [on\|off]` | Generic flag toggle — writes/removes `~/.local/state/omarchy/toggles/<flag>` |
| `omarchy toggle idle <action>` | **Dedicated** idle command (`omarchy-toggle-idle`) — writes `~/.local/state/omarchy/indicators/stay-awake` |
| `omarchy toggle screensaver` | Dedicated screensaver toggle (`omarchy-toggle-screensaver`) |
| `omarchy-shell notifications setDnd <on\|off>` | IPC call to the running Omarchy shell to control Do Not Disturb |
| `omarchy-powerprofiles-set <context> <profile>` | Sets and persists power profile for AC/battery context |

> `omarchy-toggle idle stay-awake` (with hyphens) does **NOT** work — the
> generic `omarchy-toggle` binary only accepts `on`, `off`, or `toggle` as its
> second argument. The idle subsystem has its own dedicated binary
> (`omarchy-toggle-idle`) that handles `stay-awake` / `allow-idle`. Always use
> `omarchy toggle idle stay-awake` (space-separated subcommand form).

---

## Reverting & Uninstalling

### Automated

```bash
./install.sh --uninstall
```

This removes:
- `~/.local/bin/omarchy-gaming-toggle`
- `~/.local/state/omarchy/toggles/hypr/gaming.lua`
- `~/.local/state/omarchy/toggles/gaming` (the active flag, if set)
- `~/.config/gamemode.ini`
- `~/.config/environment.d/gaming.conf`
- The keybinding block from `~/.config/hypr/bindings.lua`

CachyOS repos and kernel are intentionally **not** removed by uninstall
(they affect system packages beyond gaming). To remove manually:

1. Remove the `[cachyos-*]` blocks from `/etc/pacman.conf`
2. `sudo pacman -Rns linux-cachyos linux-cachyos-headers`
3. Remove mirrorlist/keyring: `sudo pacman -Rns cachyos-keyring cachyos-mirrorlist cachyos-v4-mirrorlist`
4. `sudo pacman -Sy`

### Manual / Emergency

```bash
# Disable gaming mode immediately
rm -f ~/.local/state/omarchy/toggles/gaming
hyprctl reload

# Restore idle and screensaver
omarchy toggle idle allow-idle
omarchy-toggle screensaver-off on

# Restore notifications
omarchy-shell notifications setDnd off

# Restore power profile
omarchy-powerprofiles-set autodetect power-saver
```

### Verify Clean State

```bash
# Should all be empty/absent/false:
ls ~/.local/state/omarchy/toggles/gaming 2>/dev/null     # Should not exist
omarchy toggle idle status                                # enabled: false
omarchy-shell notifications setDnd off                    # off
powerprofilesctl get                                      # power-saver or balanced
```
