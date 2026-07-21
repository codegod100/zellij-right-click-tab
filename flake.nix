{
  description = "Zellij with right-click to close tabs (patched binary + tab-bar plugin)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      rust-overlay,
      flake-utils,
    }:
    # eachDefaultSystem includes x86_64-darwin; nixpkgs-unstable dropped it (26.11+).
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ] (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ (import rust-overlay) ];
        };

        # Stock zellij patched so unselectable plugins (tab bar) receive right-clicks.
        zellij-unwrapped = pkgs.zellij-unwrapped.overrideAttrs (old: {
          pname = "zellij-unwrapped-rightclick";
          patches = (old.patches or [ ]) ++ [
            ./patches/zellij-right-click-unselectable.patch
          ];
        });

        zellij = pkgs.zellij.override { inherit zellij-unwrapped; };

        rustWasm = pkgs.rust-bin.stable.latest.default.override {
          targets = [ "wasm32-wasip1" ];
        };

        rustPlatformWasm = pkgs.makeRustPlatform {
          cargo = rustWasm;
          rustc = rustWasm;
        };

        tab-bar-right-close = rustPlatformWasm.buildRustPackage {
          pname = "zellij-tab-bar-right-close";
          version = "0.1.0";
          src = ./tab-bar;

          cargoLock.lockFile = ./tab-bar/Cargo.lock;

          doCheck = false;

          # buildRustPackage defaults to host triple; we only want the wasm artifact.
          buildPhase = ''
            runHook preBuild
            cargo build --release --target wasm32-wasip1 -j "$NIX_BUILD_CORES"
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            mkdir -p "$out/share/zellij/plugins"
            cp target/wasm32-wasip1/release/tab-bar-right-close.wasm \
              "$out/share/zellij/plugins/tab-bar-right-close.wasm"
            runHook postInstall
          '';
        };

        # Patched zellij + plugin wasm + config snippet
        with-plugin = pkgs.symlinkJoin {
          name = "zellij-right-click-tab";
          paths = [
            zellij
            tab-bar-right-close
          ];
          postBuild = ''
            mkdir -p "$out/share/zellij"
            cat > "$out/share/zellij/config-snippet.kdl" <<EOF
            // Merge into ~/.config/zellij/config.kdl (plugins block).
            // Fully quit Zellij after changing aliases / binary.
            tab-bar location="file:$out/share/zellij/plugins/tab-bar-right-close.wasm"
            EOF
          '';
          meta = {
            description = "Patched Zellij + tab-bar plugin: right-click closes tabs";
            mainProgram = "zellij";
          };
        };
      in
      {
        packages = {
          default = with-plugin;
          zellij = zellij;
          zellij-unwrapped = zellij-unwrapped;
          tab-bar-right-close = tab-bar-right-close;
          with-plugin = with-plugin;
        };

        apps.default = {
          type = "app";
          program = "${zellij}/bin/zellij";
        };

        devShells.default = pkgs.mkShell {
          packages = [
            rustWasm
            zellij
          ];
          shellHook = ''
            echo "zellij-right-click-tab"
            echo "  (cd tab-bar && cargo build --release --target wasm32-wasip1)"
            echo "  nix build .#zellij"
            echo "  nix build .#tab-bar-right-close"
          '';
        };

        checks.zellij = zellij;
        checks.tab-bar-right-close = tab-bar-right-close;
      }
    )
    // {
      overlays.default = final: prev: {
        zellij-right-click-tab = self.packages.${prev.stdenv.hostPlatform.system}.default;
        zellij = self.packages.${prev.stdenv.hostPlatform.system}.zellij;
      };

      homeModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          inherit (lib)
            mkEnableOption
            mkIf
            mkOption
            types
            ;
          cfg = config.programs.zellij-right-click-tab;
          sys = pkgs.stdenv.hostPlatform.system;
          flakePkgs = self.packages.${sys};
        in
        {
          options.programs.zellij-right-click-tab = {
            enable = mkEnableOption "Zellij with right-click to close tabs";

            package = mkOption {
              type = types.package;
              default = flakePkgs.zellij;
              defaultText = lib.literalExpression "self.packages.\${system}.zellij";
              description = "Patched Zellij package.";
            };

            tabBarPackage = mkOption {
              type = types.package;
              default = flakePkgs.tab-bar-right-close;
              defaultText = lib.literalExpression "self.packages.\${system}.tab-bar-right-close";
              description = "Package providing tab-bar-right-close.wasm.";
            };
          };

          config = mkIf cfg.enable {
            home.packages = [ cfg.package ];

            xdg.configFile."zellij/plugins/tab-bar-right-close.wasm".source =
              "${cfg.tabBarPackage}/share/zellij/plugins/tab-bar-right-close.wasm";

            xdg.configFile."zellij/right-click-tab.kdl".text = ''
              // Generated by programs.zellij-right-click-tab
              // Copy the plugins entry into config.kdl (or include this file if you split config).
              plugins {
                  tab-bar location="file:${config.xdg.configHome}/zellij/plugins/tab-bar-right-close.wasm"
              }
            '';
          };
        };
    };
}
