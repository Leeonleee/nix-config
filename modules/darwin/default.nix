{ ... }:

{
  nixpkgs.config.allowUnfree = true;

  homebrew.enable = true;

  environment.systemPath = [
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
  ];
}
