{ lib, pkgs, pkgsUnstable, ... }:

{
  imports = [
    ../home-manager-unstable.nix
    ../programs/herdr.nix
    ../programs/pi.nix
    ../programs/claude-code.nix
  ];

  # Convenient baseline toolchains for scripts and small projects. Keep
  # project-specific versions and dependencies in a flake or dev shell.
  home.packages = with pkgs; [
    go
    gopls

    rustc
    cargo
    rustfmt
    clippy
    rust-analyzer

    nodejs
    python3
    uv

    jdk21
    maven
    gradle

    gcc
    gnumake
    cmake
    pkg-config
    clang-tools

    codecrafters-cli
    awscli2
    dig
    postgresql
    terraform

    dua
  ]
  ++ lib.optionals pkgs.stdenv.isLinux [
    pkgs.gdb
  ]
  ++ [
    llama-cpp
  ];

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.bat.enable = true;

  # tealdeer needs its page cache downloaded before `tldr` works offline.
  programs.tealdeer = {
    enable = true;
    settings.updates.auto_update = true;
  };

  programs.lazygit.enable = true;
  programs.lazydocker.enable = true;
  programs.btop.enable = true;
}
