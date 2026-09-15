{ pkgs, ... }:

{
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
    gdb

    jq
    ripgrep
    fd
  ];

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };
}
