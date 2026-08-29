{ inputs, ... }:

{
  # Compatibility shim for modules not yet available in the release branch.
  # Remove these imports once the release Home Manager provides them.
  imports = [
    "${inputs.home-manager-unstable}/modules/programs/pi-coding-agent.nix"
    "${inputs.home-manager-unstable}/modules/programs/herdr.nix"
  ];
}
