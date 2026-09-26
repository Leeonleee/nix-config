{ config, inputs, pkgs, ... }:

{
  programs.claude-code = {
    enable = true;
    package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;
    # Claude Code reads CLAUDE.md; share the global AGENTS.md used by other agents.
    context = ./agents/AGENTS.md;

    settings = {
      attribution = {
        commit = "";
        pr = "";
        sessionUrl = false;
      };
    };
  };
  home.file."${config.programs.claude-code.configDir}/settings.json".force = true;
}
