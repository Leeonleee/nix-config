{ inputs, pkgsUnstable, ... }:
{
  imports = [
    "${inputs.home-manager-unstable}/modules/programs/pi-coding-agent.nix"
  ];
  programs.pi-coding-agent = {
    enable = true;
    package = pkgsUnstable.pi-coding-agent;

    settings = {
      defaultProvider = "openai";
      defaultThinkingLevel = "high";
    };
  };
}
