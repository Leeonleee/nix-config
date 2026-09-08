{ pkgs, ... }:

{
  programs.zsh = {
    enable = true;

    initContent = ''
    if [[ -x /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
  '';

    shellAliases = {
      rebuild-check = "nix --extra-experimental-features 'nix-command flakes' flake check --no-build ~/nix-config";

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