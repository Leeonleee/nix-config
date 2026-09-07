{ pkgs, pkgsUnstable, config, ... }:

let
  wrappedPi = pkgs.symlinkJoin {
    name = "pi-coding-agent";

    paths = [
      pkgsUnstable.pi-coding-agent
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
        "npm:pi-subagents@0.65.0"
        "npm:pi-btw"
        "npm:pi-clear-screen"
        "npm:pi-simplify"
      ];
    };
  };
}
