{ config, inputs, lib, pkgs, ... }:

let
  tuiKeys = config.programs.herdr.settings.keys or { };

  # Herdr TUI action -> herdr-app command. TUI-only modes (resize, navigate,
  # scrollback editing, pane rename/cycle) have no app equivalent.
  globalActions = {
    help = "app.help";
    settings = "app.settings";
    detach = "window.close";
    workspace_picker = "mod.open:picker";
    goto = "app.palette";
    new_workspace = "space.new";
    rename_workspace = "space.rename";
    close_workspace = "space.close";
    new_tab = "tab.new";
    rename_tab = "tab.rename";
    previous_tab = "tab.prev";
    next_tab = "tab.next";
    close_tab = "tab.close";
    switch_tab = "tab.select";
    switch_workspace = "space.select";
    focus_pane_left = "pane.go:left";
    focus_pane_down = "pane.go:down";
    focus_pane_up = "pane.go:up";
    focus_pane_right = "pane.go:right";
    split_vertical = "pane.split:right";
    split_horizontal = "pane.split:down";
    close_pane = "pane.close";
    zoom = "pane.zoom";
    toggle_sidebar = "layout.toggle:sidebar";
  };
  terminalActions = {
    remote_image_paste = "terminal.paste_image";
  };

  # "ctrl+s" -> "ctrl-s"; "prefix+shift+x" -> "ctrl-s shift-x".
  keyNames = {
    minus = "-";
    "?" = "shift-/";
  };
  chord = s: lib.concatMapStringsSep "-" (k: keyNames.${k} or k) (lib.splitString "+" s);
  prefix = chord (tuiKeys.prefix or "ctrl+s");
  keystroke =
    s: if lib.hasPrefix "prefix+" s then "${prefix} ${chord (lib.removePrefix "prefix+" s)}" else chord s;

  # A TUI binding becomes one app binding, or nine for a "1..9" range.
  bindingsFor =
    action: command:
    let
      key = tuiKeys.${action} or "";
    in
    if key == "" then
      { }
    else if lib.hasSuffix "1..9" key then
      lib.listToAttrs (
        map (n: {
          name = keystroke "${lib.removeSuffix "1..9" key}${toString n}";
          value = "${command}:${toString n}";
        }) (lib.range 1 9)
      )
    else
      { ${keystroke key} = command; };
  bindings = actions: lib.mergeAttrsList (lib.mapAttrsToList bindingsFor actions);

  defaults = lib.importJSON ./keys.json;
in
{
  home.packages = [ inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.herdr-app ];

  # Shipped defaults (copied from a fresh install) plus the Herdr TUI keys.
  # The app does not merge this file with newer defaults; refresh keys.json
  # from a fresh install to pick them up.
  # force: the app writes its own keys.json on first start.
  xdg.configFile."herdr-app/keys.json" = {
    force = true;
    text = builtins.toJSON (
      lib.recursiveUpdate defaults {
        global = bindings globalActions;
        terminal = bindings terminalActions;
      }
    );
  };
}
