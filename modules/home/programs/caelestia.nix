{ config, lib, pkgsUnstable, ... }:
let
  shell = pkgsUnstable.caelestia-shell;
  colours = config.lib.stylix.colors;
  # Caelestia consumes Material 3 roles, not Base16 or Qt application colours.
  # Keep this bridge local until Stylix provides a Caelestia target.
  roles = {
    base00 = [ "background" "surface" "surfaceDim" "surfaceContainerLowest" "shadow" "scrim" "onPrimary" "onSecondary" "onTertiary" "onError" "onSuccess" "onPrimaryFixed" "onSecondaryFixed" "onTertiaryFixed" "inverseOnSurface" ];
    base01 = [ "surfaceContainerLow" "surfaceContainer" "primaryContainer" "secondaryContainer" "tertiaryContainer" "errorContainer" "successContainer" ];
    base02 = [ "surfaceBright" "surfaceContainerHigh" "surfaceContainerHighest" "surfaceVariant" "outlineVariant" ];
    base03 = [ "outline" "neutral_variant_paletteKeyColor" ];
    base04 = [ "onSurfaceVariant" ];
    base05 = [ "onBackground" "onSurface" "inverseSurface" "neutral_paletteKeyColor" ];
    base08 = [ "error" "onErrorContainer" ];
    base0B = [ "success" "onSuccessContainer" ];
    base0C = [ "secondary" "secondary_paletteKeyColor" "onSecondaryContainer" "secondaryFixed" "secondaryFixedDim" "onSecondaryFixedVariant" ];
    base0D = [ "primary" "primary_paletteKeyColor" "surfaceTint" "inversePrimary" "onPrimaryContainer" "primaryFixed" "primaryFixedDim" "onPrimaryFixedVariant" ];
    base0E = [ "tertiary" "tertiary_paletteKeyColor" "onTertiaryContainer" "tertiaryFixed" "tertiaryFixedDim" "onTertiaryFixedVariant" ];
  };
  palette = lib.listToAttrs (lib.concatLists (lib.mapAttrsToList
    (base: names: map (name: lib.nameValuePair name colours.${base}) names)
    roles));
  terminalBases = [ "base00" "base08" "base0B" "base0A" "base0D" "base0E" "base0C" "base05" "base03" "base08" "base0B" "base0A" "base0D" "base0E" "base0C" "base07" ];
  schemeFile = config.home.file."${config.xdg.stateHome}/caelestia/scheme.json";
  shellConfig = config.xdg.configFile."caelestia/shell.json";
in
{
  home.packages = [
    shell
    pkgsUnstable.caelestia-cli
  ];

  # The upstream shell reads this state path directly. Manage it as a read-only
  # HM file: change themes here, not with the shell's interactive scheme editor.
  home.file."${config.xdg.stateHome}/caelestia/scheme.json".text = builtins.toJSON {
    name = "Stylix";
    flavour = "Base16";
    mode = if config.stylix.polarity == "light" then "light" else "dark";
    colours = palette // lib.listToAttrs (lib.imap0
      (i: base: lib.nameValuePair "term${toString i}" colours.${base})
      terminalBases);
  };

  # Only override theme settings; all shell behaviour retains upstream defaults.
  xdg.configFile."caelestia/shell.json".text = builtins.toJSON {
    appearance.font = {
      headline.family = config.stylix.fonts.sansSerif.name;
      title.family = config.stylix.fonts.sansSerif.name;
      body.family = config.stylix.fonts.sansSerif.name;
      label.family = config.stylix.fonts.sansSerif.name;
      mono.family = config.stylix.fonts.monospace.name;
      clock = config.stylix.fonts.sansSerif.name;
      workspaces = config.stylix.fonts.sansSerif.name;
    };
  };
  xdg.configFile."caelestia/cli.json".text = "{}";

  # Never attach this to graphical-session.target: Niri has its own shell.
  # Home Manager's Hyprland systemd integration starts/stops this target.
  systemd.user.services.caelestia = {
    Unit = {
      Description = "Caelestia Shell";
      After = [ "hyprland-session.target" ];
      Requisite = [ "hyprland-session.target" ];
      PartOf = [ "hyprland-session.target" ];
      X-Restart-Triggers = [
        "${shellConfig.source}"
        "${schemeFile.source}"
      ];
    };
    Service = {
      Type = "exec";
      ExecStart = "${shell}/bin/caelestia-shell";
      Restart = "on-failure";
      RestartSec = "5s";
      TimeoutStopSec = "5s";
      # Breeze's Qt Quick controls pull in KDE QML modules outside this
      # package's closure. Caelestia supplies its own Stylix-backed styling.
      Environment = [
        "QT_QPA_PLATFORM=wayland"
        "QT_QUICK_CONTROLS_STYLE=Basic"
        "QT_QPA_PLATFORMTHEME="
        "QT_STYLE_OVERRIDE="
      ];
      Slice = "session.slice";
    };
    Install.WantedBy = [ "hyprland-session.target" ];
  };
}
