{ inputs, pkgs, ... }:
let
  unstable = import inputs.nixpkgs-unstable {
    system = pkgs.system;
  };
in
{

  imports = [
    "${inputs.home-manager-unstable}/modules/programs/herdr.nix"
  ];

  programs.herdr = {
    enable = true;
    package = unstable.herdr;

    settings = {

    };
  };

  xdg.configFile."herdr/config.toml".source = ./config.toml;
}
