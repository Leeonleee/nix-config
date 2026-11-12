{ inputs, lib, pkgs, pkgsUnstable, ... }:

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
      inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.herdr-core
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

  programs.yazi = {
    enable = true;
    package = pkgsUnstable.yazi;
    enableZshIntegration = true;
  };

  programs.home-manager.enable = true;
}
