{ pkgs, ... }:

{
  programs.zsh = {
    enable = true;

    shellAliases = {
      rebuild =
        if pkgs.stdenv.isDarwin
        then "sudo darwin-rebuild switch --flake ~/nix-config#mac"
        else "sudo nixos-rebuild switch --flake ~/nix-config#$(hostname)";

      rebuild-test =
        if pkgs.stdenv.isDarwin
        then "sudo darwin-rebuild check --flake ~/nix-config#$mac"
        else "sudo nixos-rebuild test --flake ~/nix-config#$(hostname)";
    };
  };
}