{ inputs, pkgs, ... }:
let
  unstable = import inputs.nixpkgs-unstable {
    system = pkgs.system;
  };
in
{
  home.packages = [
    unstable.herdr
  ];

  xdg.configFile."herdr/config.toml".source = ./config.toml;
}
