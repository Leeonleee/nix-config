{ pkgs, ... }:

{
  programs.zsh = {
    enable = true;

    shellAliases = {
      rebuild = "sudo nixos-rebuild switch --flake ~/nix-config#framework";
    };
  };

}
