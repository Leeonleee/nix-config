{ inputs, ... }:

{
  imports = [
    "${inputs.home-manager-unstable}/modules/programs/pi-coding-agent.nix"
    "${inputs.home-manager-unstable}/modules/programs/herdr.nix"
  ];
}
