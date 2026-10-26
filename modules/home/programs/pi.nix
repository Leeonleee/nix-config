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

  # Pi has no Stylix target; map its theme roles to the shared palette.
  stylixTheme = with config.lib.stylix.colors.withHashtag; {
    name = "stylix";

    vars = {
      bg = base00;
      surface = base01;
      selection = base02;
      comment = base03;
      subtext = base04;
      text = base05;
      red = base08;
      orange = base09;
      yellow = base0A;
      green = base0B;
      cyan = base0C;
      blue = base0D;
      magenta = base0E;
    };

    colors = {
      accent = "blue";
      border = "blue";
      borderAccent = "cyan";
      borderMuted = "selection";
      success = "green";
      error = "red";
      warning = "yellow";
      muted = "subtext";
      dim = "comment";
      text = "text";
      thinkingText = "subtext";

      selectedBg = "selection";
      scrollbarTrack = "selection";
      scrollbarThumb = "subtext";
      searchMatchBg = "selection";
      searchMatchText = "text";
      userMessageBg = "surface";
      userMessageText = "text";
      customMessageBg = "surface";
      customMessageText = "text";
      customMessageLabel = "magenta";
      toolPendingBg = "surface";
      toolSuccessBg = "surface";
      toolErrorBg = "selection";
      toolTitle = "text";
      toolOutput = "subtext";

      mdHeading = "yellow";
      mdLink = "blue";
      mdLinkUrl = "comment";
      mdCode = "cyan";
      mdCodeBlock = "green";
      mdCodeBlockBorder = "comment";
      mdQuote = "subtext";
      mdQuoteBorder = "comment";
      mdHr = "comment";
      mdListBullet = "blue";

      toolDiffAdded = "green";
      toolDiffRemoved = "red";
      toolDiffContext = "subtext";

      syntaxComment = "comment";
      syntaxKeyword = "magenta";
      syntaxFunction = "blue";
      syntaxVariable = "red";
      syntaxString = "green";
      syntaxNumber = "orange";
      syntaxType = "yellow";
      syntaxOperator = "cyan";
      syntaxPunctuation = "text";

      thinkingOff = "selection";
      thinkingMinimal = "comment";
      thinkingLow = "cyan";
      thinkingMedium = "blue";
      thinkingHigh = "magenta";
      thinkingXhigh = "orange";
      thinkingMax = "red";

      bashMode = "green";
    };

    export = {
      pageBg = "bg";
      cardBg = "surface";
      infoBg = "selection";
    };
  };
in
{
  home.file.".pi/agent/themes/stylix.json".text = builtins.toJSON stylixTheme;

  programs.pi-coding-agent = {
    enable = true;

    package = wrappedPi;
    context = ./agents/AGENTS.md;

    settings = {
      defaultProvider = "claude-bridge";
      defaultThinkingLevel = "medium";
      defaultModel = "claude-opus-5-5";
      theme = stylixTheme.name;

      skills = [
        "${config.home.homeDirectory}/agents/skills"
      ];

      packages = [

        "npm:@juicesharp/rpiv-ask-user-question" # ask user questions
        "npm:pi-web-access" # allow agent to access web
        "npm:@tintinweb/pi-subagents"
        "npm:pi-lens" # allow agent to see errors/warnings in code
        "npm:@juicesharp/rpiv-todo" # show progress of agent work
        "npm:@narumitw/pi-plan-mode" # plan mode

        "npm:pi-claude-code-ui"

        "npm:pi-init"
        "npm:pi-btw"
        "npm:pi-clear-screen"

        "npm:pi-claude-bridge" # Claude subscription models via Claude Code
      ];
    };
  };
}
