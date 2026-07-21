# zellij-right-click-tab

Right-click a Zellij tab to close it.

Upstream Zellij never delivers right-clicks to the tab bar (it is unselectable, so mouse routing stops at “not the active pane”). This flake provides:

1. **A patched `zellij` binary** — routes right-click presses on unselectable panes to the plugin API (`handle_right_click`).
2. **A tab-bar plugin** (fork of the 0.44 stock bar) — closes the tab under the cursor on right-click.

## Requirements

- Zellij **0.44.x** (patch is against nixpkgs `zellij-unwrapped` 0.44.3).
- Mouse mode enabled (default).

## Quick install (profile)

```bash
# Patched binary + plugin wasm in the store
nix profile install github:YOU/zellij-right-click-tab
# or, from a local clone:
nix profile install .
```

Point your tab-bar alias at the wasm (path from the installed package):

```kdl
// ~/.config/zellij/config.kdl
plugins {
    tab-bar location="file:/nix/store/...-zellij-tab-bar-right-close/share/zellij/plugins/tab-bar-right-close.wasm"
}
```

Easier: install only the packages and use a fixed path under your config:

```bash
nix build .#tab-bar-right-close
cp result/share/zellij/plugins/tab-bar-right-close.wasm ~/.config/zellij/plugins/
nix profile install .#zellij   # replaces stock zellij if present
```

```kdl
plugins {
    tab-bar location="file:/home/YOU/.config/zellij/plugins/tab-bar-right-close.wasm"
}
```

**Fully quit Zellij** after changing the binary or the `tab-bar` alias (session resurrection may still embed `zellij:tab-bar` until you start a fresh session or rewrite the saved layout).

Grant plugin permissions once if prompted (`ReadApplicationState`, `ChangeApplicationState`), or pre-grant in `~/.cache/zellij/permissions.kdl`:

```kdl
"/home/YOU/.config/zellij/plugins/tab-bar-right-close.wasm" {
    ChangeApplicationState
    ReadApplicationState
}
```

## Packages

| Attribute | What |
|-----------|------|
| `default` / `with-plugin` | Patched `zellij` + wasm + `share/zellij/config-snippet.kdl` |
| `zellij` | Patched wrapper (like nixpkgs `zellij`) |
| `zellij-unwrapped` | Patched unwrapped binary |
| `tab-bar-right-close` | Plugin package (`share/zellij/plugins/*.wasm`) |

```bash
nix build .#zellij
nix build .#tab-bar-right-close
nix run .#zellij
```

## Home Manager

```nix
# flake inputs
zellij-right-click-tab.url = "github:YOU/zellij-right-click-tab";

# home-manager module
imports = [ inputs.zellij-right-click-tab.homeModules.default ];

programs.zellij-right-click-tab.enable = true;
```

Then merge the generated `~/.config/zellij/right-click-tab.kdl` `plugins` entry into your real `config.kdl`.

## Overlay

```nix
nixpkgs.overlays = [ inputs.zellij-right-click-tab.overlays.default ];
# replaces pkgs.zellij with the patched build
```

## Dev shell

```bash
nix develop
cd tab-bar && cargo build --release --target wasm32-wasip1
```

## How it works

Stock mouse handling (simplified):

- **Left-click** on the tab bar → focus path → `start_selection` → plugin `Mouse::LeftClick`
- **Right-click** on a non-active pane → **`NoAction`** (tab bar never receives it)

Patch (`patches/zellij-right-click-unselectable.patch`): on right-click **press** over a non-focused pane, call `pane.handle_right_click`, which for plugins becomes `Mouse::RightClick`.

Plugin (`tab-bar/`): on `Mouse::RightClick`, resolve column → tab index → `close_tab_with_index`.

## Resurrected sessions

Saved layouts often hard-code `plugin location="zellij:tab-bar"`. The config alias is ignored for those. Either:

- Start a **new** session after setting the alias, or
- Replace `zellij:tab-bar` with your `file:…` path in  
  `~/.cache/zellij/contract_version_1/session_info/<name>/session-layout.kdl`  
  then re-attach.

## License

- Patch: same as Zellij (MIT)
- Tab-bar plugin: based on Zellij default tab-bar (MIT)
