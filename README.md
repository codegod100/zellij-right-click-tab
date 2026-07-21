# zellij-right-click-tab

Right-click a Zellij tab to close it. Double-click empty tab-bar space to open a new tab.

Upstream Zellij never delivers right-clicks to the tab bar (it is unselectable, so mouse routing stops at “not the active pane”). This flake provides:

1. **A patched `zellij` binary** — routes right-click presses on unselectable panes to the plugin API (`handle_right_click`).
2. **A tab-bar plugin** (fork of the 0.44 stock bar) — closes the tab under the cursor on right-click.

## Requirements

- Zellij **0.44.x** (patch is against nixpkgs `zellij-unwrapped` 0.44.3).
- Mouse mode enabled (default).


## CI / FlakeHub Cache

GitHub Actions (`.github/workflows/flakehub-ci.yml`) runs **Determinate CI**:

- Installs Determinate Nix
- Authenticates to **FlakeHub Cache** via OIDC (no static secrets)
- Builds flake packages / checks for discovered systems

Push to `main` / open a PR / run **workflow_dispatch** to populate the cache.

**Notes:**

- Real cache **push** needs a [FlakeHub](https://flakehub.com/signup) plan with Cache; without it builds can still succeed but push may log HTTP 401.
- Fork PRs do not get FlakeHub Cache auth.
- Local pulls: `determinate-nixd login` (or your usual Determinate Nix setup).

After CI has built once:

```bash
nix build github:YOU/zellij-right-click-tab#zellij
nix build github:YOU/zellij-right-click-tab#tab-bar-right-close
```

## Quick start

```bash
# One-shot: patched binary + flake config (tab-bar plugin wired in)
nix run github:codegod100/zellij-right-click-tab

# Or from a local clone
nix run .
```

The default app/package wraps `zellij` with `--config` pointing at a store
`config.kdl` that only sets:

```kdl
plugins {
    tab-bar location="file:/nix/store/…/tab-bar-right-close.wasm"
}
```

Other settings stay at Zellij defaults. To use your own config instead, set
`ZELLIJ_CONFIG_FILE` / `ZELLIJ_CONFIG_DIR` or pass `-c` / `--config` (the
wrapper will not override those).

### Install into profile

```bash
nix profile install github:codegod100/zellij-right-click-tab
# then:
zellij   # uses wrapped binary + flake config
```

### Custom ~/.config/zellij/config.kdl

Merge the plugins alias yourself (path from `nix build .#tab-bar-right-close`):

```kdl
plugins {
    tab-bar location="file:/nix/store/…/share/zellij/plugins/tab-bar-right-close.wasm"
}
```

**Fully quit Zellij** after changing the binary or the `tab-bar` alias (session resurrection may still embed `zellij:tab-bar` until you start a fresh session or rewrite the saved layout).

## Packages

| Attribute | What |
|-----------|------|
| `default` / `with-plugin` | Wrapped `zellij` + wasm + store `config.kdl` |
| `zellij` | Same wrapper (for `nix run .#zellij`) |
| `zellij-bin` | Patched binary only (no config wrapper) |
| `config` | The generated `config.kdl` derivation |
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
