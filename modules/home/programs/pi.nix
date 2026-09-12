{ config, inputs, pkgs, ... }:

let
  wrappedPi = pkgs.symlinkJoin {
    name = "pi-coding-agent";

    paths = [
      inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi
    ];

    nativeBuildInputs = [
      pkgs.makeWrapper
    ];

    postBuild = ''
      wrapProgram $out/bin/pi \
        --set NPM_CONFIG_PREFIX ${config.home.homeDirectory}/.pi/npm
    '';
  };
in
{
  programs.pi-coding-agent = {
    enable = true;

    package = wrappedPi;

    extraPackages = [
      pkgs.nodejs_latest
    ];

    settings = {
      defaultProvider = "openai-codex";
      defaultThinkingLevel = "medium";
      defaultModel = "gpt-6-astra";

      skills = [
        "${config.home.homeDirectory}/agents/skills"
      ];

      packages = [
        "npm:pi-init"
        "npm:pi-subagents"
        "npm:pi-btw"
        "npm:pi-clear-screen"
        "npm:pi-simplify"
        "npm:@narumitw/pi-plan-mode"
      ];
    };
  };
}
