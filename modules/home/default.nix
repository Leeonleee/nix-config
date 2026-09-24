{ lib, pkgs, ... }:

{
  imports = [
    ../theme.nix
    ./programs/zsh.nix
    ./programs/fastfetch.nix
    ./programs/neovim
    ./programs/starship
    ./programs/eza.nix
    ./programs/lsy.nix
  ];
  stylix.targets = {
    starship.enable = false;
    gtk.enable = false;
  };

  home.packages =
    with pkgs;
    [
      lsof
      gh
      jq
      ripgrep
      fd
    ]
    ++ lib.optionals stdenv.isLinux [
      usbutils
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

  programs.home-manager.enable = true;
}
