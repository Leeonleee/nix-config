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
  ];
}
