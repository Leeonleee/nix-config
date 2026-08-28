{ config, pkgs, ... }:

{
  imports = [
    ./programs/zsh.nix
    ./programs/fastfetch.nix
    ./programs/neovim.nix
    ./programs/kitty.nix
  ];

  home.username = "leonl";
  home.homeDirectory = "/home/leonl";

  home.stateVersion = "26.05";
  
  home.packages = with pkgs; [
    bitwarden-desktop
    google-chrome
    wl-clipboard
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

  programs.starship = {
    enable = true;
  };

  programs.vesktop.enable = true;

  programs.home-manager.enable = true;
}
