{ pkgs, ... }:

{
  programs.zsh = {
    enable = true;

    shellAliases = {
      rebuild = "sudo nixos-rebuild switch --flake ~/nix-config#$(hostname)";
      rebuild-test = "sudo nixos-rebuild test --flake ~/nix-config#$(hostname)";
    };
  };

}
