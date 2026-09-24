{ config, lib, pkgs, ... }:

{
  programs.vscode = {
    enable = true;
    # Keep existing Marketplace extensions and allow installing more in VS Code.
    mutableExtensionsDir = true;

    profiles.default.userSettings =
      builtins.fromJSON (builtins.readFile ./settings.json)
      // {
        "terminal.integrated.fontFamily" = config.stylix.fonts.monospace.name;
      }
      // lib.optionalAttrs pkgs.stdenv.isLinux {
        "vscode-neovim.neovimExecutablePaths.linux" = "/etc/profiles/per-user/${config.home.username}/bin/nvim";
        "qt-core.additionalQtPaths" = [
          {
            name = "Qt-6.11.1-linux-g++-x86_64_from_PATH";
            path = "/run/current-system/sw/bin/qtpaths";
          }
        ];
      };
  };

  # Stylix supplies the theme extension, colour selection, and editor fonts.
  stylix.targets.vscode.enable = true;
}
