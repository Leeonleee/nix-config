{ config, pkgs, ... }:

{
  home.username = "leonl";
  home.homeDirectory = "/home/leonl";

  home.stateVersion = "26.05";
  
  home.packages = with pkgs; [
    bitwarden-desktop
    google-chrome
  ];

  programs.git = {
    enable = true;

    settings = {
      user = {
        name = "Leon Lee";
	email = "leonlee20031219@gmail.com";
      };

      init.defaultBranch = "main";
    };
  };

  programs.zsh = {
    enable = true;

    shellAliases = {
      rebuild = "sudo nixos-rebuild switch --flake ~/nix-config#framework";
    };
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  programs.starship = {
    enable = true;
  };

  programs.home-manager.enable = true;
}
