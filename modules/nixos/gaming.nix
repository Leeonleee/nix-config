{ ... }:

{
  # The NixOS module also enables the 32-bit graphics stack Steam requires.
  programs.steam.enable = true;
}
