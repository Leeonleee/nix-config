{ inputs, pkgsUnstable, ... }:
{
  programs.pi-coding-agent = {
    enable = true;
    package = pkgsUnstable.pi-coding-agent;

    settings = {
      defaultProvider = "openai";
      defaultThinkingLevel = "high";
    };
  };
}
