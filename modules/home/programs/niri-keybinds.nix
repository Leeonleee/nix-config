{ config, lib, pkgs, ... }:

let
  # Read at runtime: generating the list into the script itself would make the
  # script depend on the binds that spawn it.
  listPath = "${config.xdg.configHome}/niri/keybinds.txt";

  capitalise = s: lib.toUpper (lib.substring 0 1 s) + lib.substring 1 (-1) s;

  # "/nix/store/<hash>-noctalia-5.1.0/bin/noctalia" -> "noctalia".
  shortenWord = word:
    let m = builtins.match "/nix/store/[^/]+/(.*/)?([^/]+)" word;
    in if m == null then word else lib.last m;
  shorten = command: lib.concatMapStringsSep " " shortenWord (lib.splitString " " command);

  scalar = v: builtins.isString v || builtins.isInt v || builtins.isFloat v || builtins.isBool v;
  showArgs = args:
    if scalar args then toString args
    else if builtins.isList args && lib.all scalar args then lib.concatMapStringsSep " " toString args
    else "";

  describeAction = action:
    let
      name = lib.head (lib.attrNames action);
      args = action.${name};
    in
    if name == "spawn" then "Run: ${shorten (showArgs args)}"
    else if name == "spawn-sh" then "Run: ${shorten args}"
    else lib.concatStringsSep " " (lib.filter (s: s != "") [
      (capitalise (lib.replaceStrings [ "-" ] [ " " ] name))
      (showArgs args)
    ]);

  describe = bind: bind.hotkey-overlay.title or (describeAction bind.action);

  entries = lib.sort (a: b: lib.toLower a.description < lib.toLower b.description) (
    lib.mapAttrsToList (key: bind: { inherit key; description = describe bind; })
      config.programs.niri.settings.binds
  );

  escape = lib.escapeXML;
  line = e: "<b>${escape e.key}</b>  <span alpha='70%'>·</span>  ${escape e.description}";

  keybinds = pkgs.writeShellApplication {
    name = "niri-keybinds";
    runtimeInputs = [ config.programs.rofi.finalPackage ];
    text = ''
      rofi -dmenu -i -markup-rows -no-custom -p Keybinds \
        -theme-str 'window { width: 900px; } listview { lines: 14; }' \
        < ${lib.escapeShellArg listPath} > /dev/null || true
    '';
  };
in
{
  options.programs.niri-keybinds.package = lib.mkOption {
    type = lib.types.package;
    readOnly = true;
    description = "Searchable Rofi list of every Niri keybinding.";
  };

  config = {
    programs.niri-keybinds.package = keybinds;
    home.packages = [ keybinds ];

    xdg.configFile."niri/keybinds.txt".text = lib.concatMapStrings (e: line e + "\n") entries;
  };
}
