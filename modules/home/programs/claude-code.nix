{ config, inputs, pkgs, ... }:

{
  programs.claude-code = {
    enable = true;
    package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;

    settings = {
      attribution = {
        commit = "";
        pr = "";
      };
    };
  };
  home.file."${config.programs.claude-code.configDir}/settings.json".force = true;
}
