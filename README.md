> [!NOTE]
> This project was created entirely through AI-assisted prompting (vibe
> coding). Review the scripts and configuration before running them.

> [!IMPORTANT]
> This is an unofficial, user-maintained project. It is not part of Omarchy.
> The plugin and menu integration are tested against **Omarchy 4.0.3** and
> require Omarchy 4.x with the current plugin, bar, and menu commands.

# omarchy-gaming

An Omarchy gaming-performance mode with a Quickshell bar plugin and AUR
packaging. It combines general Linux gaming optimizations with optional
CachyOS kernel/repository setup and includes a CS2-specific latency rule.

The project currently targets Omarchy 4.0.3 APIs, including
`omarchy plugin enable`, `omarchy bar`, the Quickshell plugin manifest format,
and `~/.config/omarchy/extensions/omarchy-menu.jsonc`. Earlier Omarchy
versions are not supported; newer versions should be checked for API changes
before upgrading.

## Install from this repository

The development repository currently keeps the PKGBUILD in `pkg/`:

```bash
git clone --branch plugin-and-aur https://github.com/eliashaugsbakk/omarchy-gaming.git \
  ~/Projects/omarchy-gaming
cd ~/Projects/omarchy-gaming/pkg
makepkg -si
```

After installation, open the Omarchy menu:

```text
Install → Gaming → Omarchy Gaming Mode
```

The setup wizard installs the user integration, adds the plugin to the bar,
adds `Super + Ctrl + G`, installs GameMode, and optionally configures CachyOS.

Choose a bar section with:

```bash
OMARCHY_GAMING_BAR_SECTION=left omarchy-gaming-setup
```

Valid sections are `left`, `center`, and `right`.

## Remove the integration

Use:

```text
Remove → Gaming → Omarchy Gaming Mode
```

Removal deletes the integration created by setup and only offers to remove
GameMode, CachyOS repositories, or the CachyOS kernel when this setup recorded
that it installed them. The currently running kernel is never removed.

## What gaming mode does

When enabled, the toggle:

- Creates `~/.local/state/omarchy/toggles/gaming` and reloads Hyprland.
- Enables direct scanout and disables animations, blur, shadows, and rounding.
- Removes workspace gaps and decoration for the gaming workspace.
- Inhibits idle/sleep, disables the screensaver, and silences notifications.
- Selects the performance power profile.
- Warns if the machine is on battery or is not running a CachyOS kernel.

The bar plugin and keyboard shortcut both call the same
`omarchy-gaming-toggle` program, so they share one state and one set of safety
checks.

## CS2-specific behavior

The default `files/gaming.lua` contains:

```lua
hl.window_rule({
  match = { class = "^cs2$" },
  immediate = true,
})
```

With Gaming Mode active, this requests immediate presentation for CS2,
allowing tearing for lower input-to-display latency. The same file enables
Hyprland direct scanout. The rule is only for CS2; add or change window rules
in `files/gaming.lua` for other games.

## GameMode and Steam

GameMode is activated per game through Steam launch options. For CS2:

```text
gamemoderun %command% -nojoy +exec autoexec.cfg
```

Without an autoexec file:

```text
gamemoderun %command% -nojoy
```

`-nojoy` and `autoexec.cfg` are CS2-specific choices; omit them for other
games.

## CachyOS and hardware notes

CachyOS setup is optional. The wizard detects the CPU tier and selects the
appropriate repository architecture when possible. Virtual machines are
treated as `generic` because they may expose the host CPU model without
reliably supporting its optimized package ABI.

The CachyOS kernel and repositories are not required for the plugin or the
general gaming configuration. They are part of the original low-latency
profile and can be skipped in a VM.

## Customization locations

| Component | Location |
|---|---|
| Toggle behavior | `files/omarchy-gaming-toggle` |
| Hyprland gaming rules | `files/gaming.lua` |
| GameMode settings | `files/gamemode.ini` |
| Shader cache setting | `files/gaming.conf` |
| Bar widget | `BarWidget.qml` |
| Plugin manifest | `manifest.json` |
| Setup/removal wizard | `files/omarchy-gaming-setup` |
| AUR packaging | `pkg/PKGBUILD` |

The setup wizard adds only its own entries to
`~/.config/omarchy/extensions/omarchy-menu.jsonc`; it does not modify
Omarchy's packaged menu under `/usr/share/omarchy/`.

## AUR packaging

The monorepo keeps the PKGBUILD in `pkg/` for development. An actual AUR
repository normally places `PKGBUILD` and `omarchy-gaming.install` at its root.
Before publishing, copy or move those files to the AUR repository root and
adjust the `source` URL as needed.

The AUR repository is separate from this source repository and normally
contains the PKGBUILD, install file, and metadata—not the whole project.

## License

MIT
