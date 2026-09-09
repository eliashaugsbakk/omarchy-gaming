# omarchy-gaming (Monorepo)

One-keybind and status bar gaming mode for [Omarchy Linux](https://omarchy.org/).

Provides:
- **Omarchy Quattro Plugin (`io.github.elias.gaming`)**: A top bar status widget (`󰊴`) that shows active status and toggles gaming mode on click.
- **AUR Package (`pkg/PKGBUILD`)**: Packages system-wide defaults, binaries, optional gaming dependencies (`gamemode`, `mangohud`, `gamescope`), and registers the plugin.
- **Standalone Compatibility**: The plugin runs independently without requiring the AUR package.

---

## 1. Using as an Omarchy Plugin (Standalone)

When installed directly as a plugin:
```bash
omarchy plugin add https://github.com/eliashaugsbakk/omarchy-gaming.git --enable
```

The plugin automatically checks for `omarchy-gaming-toggle` on `$PATH`. If not present, it natively dispatches Omarchy shell toggle commands (`omarchy-toggle gaming on/off`, `omarchy-shell notifications setDnd`, `omarchy toggle idle stay-awake`, and `omarchy-powerprofiles-set`).

---

## 2. Using via AUR Package

To build and install the complete package (including CLI toggles and default configs):

```bash
cd pkg
makepkg -si
```

---

## 3. System-Specific Customizations

For custom hardware or game-specific tweaks:
- **Kernel/Repos:** Keep CachyOS / BORE kernel setup as optional / modular.
- **Compositor Rules:** Edit `files/gaming.lua` to add custom window rules for your games.
