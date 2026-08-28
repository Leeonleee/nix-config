{ config, pkgs, ... }:

{
  imports = [
    ./programs/zsh/zsh.nix
    ./programs/fastfetch/fastfetch.nix
    ./programs/neovim/neovim.nix
    ./programs/kitty/kitty.nix
    ./programs/starship/starship.nix
  ];

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


  programs.vesktop.enable = true;

  programs.home-manager.enable = true;
}
