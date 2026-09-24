{ config, lib, pkgs, ... }:

let
  capture = lib.getExe config.programs.capture.package;
  # A single source for Hyprland's described bindings and the searchable viewer.
  binding = kind: mods: key: description: dispatcher: argument: {
    inherit kind mods key description dispatcher argument;
  };
  bind = binding "bindd";
  repeat = binding "binded";
  locked = binding "bindld";
  lockedRepeat = binding "bindeld";
  exec = mods: key: description: command: bind mods key description "exec" command;

  screenshot = pkgs.writeShellApplication {
    name = "hyprland-screenshot";
    runtimeInputs = [ pkgs.coreutils pkgs.grimblast ];
    text = ''
      directory="$HOME/Pictures/Screenshots"
      mkdir -p "$directory"
      file="$directory/Screenshot-$(date +%Y-%m-%d_%H-%M-%S-%N).png"
      grimblast --notify copysave "$1" "$file"
    '';
  };

  bindings = [
    # viewer only consumes labels, so this self-reference does not recurse.
    (exec "SUPER SHIFT" "slash" "Show keybindings" (lib.getExe viewer))
    (exec "SUPER" "Return" "Open terminal" "kitty")
    (exec "SUPER" "space" "Open Vicinae" "vicinae toggle")
    # IPC verified against the Caelestia module's installed 2.5.0 package.
    (exec "SUPER ALT" "L" "Lock screen" "caelestia-shell ipc call lock lock")
    (exec "SUPER" "P" "Toggle Caelestia dashboard" "caelestia-shell ipc call drawers toggle dashboard")
    (exec "SUPER SHIFT" "space" "Toggle Caelestia launcher" "caelestia-shell ipc call drawers toggle launcher")
    (exec "SUPER" "T" "Open Dolphin" "dolphin")
    (locked "SUPER ALT" "S" "Toggle screen reader" "exec" "${pkgs.procps}/bin/pkill orca || exec orca")
    (bind "SUPER" "Q" "Close window" "killactive" "")
    (bind "SUPER" "U" "Previous workspace" "workspace" "-1")
    (bind "SUPER" "I" "Next workspace" "workspace" "+1")
    (bind "SUPER CTRL" "U" "Move window to previous workspace" "movetoworkspace" "-1")
    (bind "SUPER CTRL" "I" "Move window to next workspace" "movetoworkspace" "+1")
    (bind "SUPER SHIFT CTRL" "Left" "Move workspace to left monitor" "movecurrentworkspacetomonitor" "l")
    (bind "SUPER SHIFT CTRL" "Right" "Move workspace to right monitor" "movecurrentworkspacetomonitor" "r")
    (bind "SUPER" "F" "Maximize window" "fullscreen" "1")
    (bind "SUPER SHIFT" "F" "Fullscreen window" "fullscreen" "0")
    (bind "SUPER" "M" "Maximize window" "fullscreen" "1")
    (bind "SUPER" "V" "Toggle floating" "togglefloating" "")
    (bind "SUPER" "W" "Toggle window group (not a Niri column)" "togglegroup" "")
    (repeat "SUPER" "minus" "Decrease width" "resizeactive" "-10% 0")
    (repeat "SUPER" "equal" "Increase width" "resizeactive" "10% 0")
    (repeat "SUPER SHIFT" "minus" "Decrease height" "resizeactive" "0 -10%")
    (repeat "SUPER SHIFT" "equal" "Increase height" "resizeactive" "0 10%")
    (bind "SUPER" "C" "Center floating window" "centerwindow" "")
    (exec "" "Print" "Screenshot region" "${lib.getExe screenshot} area")
    (exec "CTRL" "Print" "Screenshot focused output" "${lib.getExe screenshot} output")
    (exec "ALT" "Print" "Screenshot active window" "${lib.getExe screenshot} active")
    # Shared capture's screenshots and colour picker use Niri IPC; do not call
    # those branches here. OCR uses grim/slurp; recording uses the portal.
    (exec "SHIFT" "Print" "Toggle screen recording" "${capture} record toggle")
    (exec "SUPER CTRL" "Print" "Copy text from region (OCR)" "${capture} ocr")
    (exec "SUPER" "Print" "Pick and copy a colour" "${lib.getExe pkgs.hyprpicker} --autocopy")
    (bind "SUPER SHIFT" "E" "Exit Hyprland" "exit" "")
    (bind "CTRL ALT" "Delete" "Exit Hyprland" "exit" "")
    (bind "SUPER SHIFT" "P" "Turn off monitors (input wakes them)" "dpms" "off")
    (lockedRepeat "" "XF86AudioRaiseVolume" "Increase volume" "exec" "${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+ -l 1.0")
    (lockedRepeat "" "XF86AudioLowerVolume" "Decrease volume" "exec" "${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-")
    (locked "" "XF86AudioMute" "Toggle audio mute" "exec" "${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
    (locked "" "XF86AudioMicMute" "Toggle microphone mute" "exec" "${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle")
    (lockedRepeat "" "XF86MonBrightnessUp" "Increase brightness" "exec" "${lib.getExe pkgs.brightnessctl} --class=backlight set +10%")
    (lockedRepeat "" "XF86MonBrightnessDown" "Decrease brightness" "exec" "${lib.getExe pkgs.brightnessctl} --class=backlight set 10%-")
  ] ++ lib.concatMap (direction: [
    (repeat "SUPER" direction.key "Focus ${direction.name}" "movefocus" direction.arg)
    (repeat "SUPER SHIFT" direction.key "Move window ${direction.name}" "movewindow" direction.arg)
    (bind "SUPER CTRL" direction.key "Focus monitor ${direction.name}" "focusmonitor" direction.arg)
    (bind "SUPER SHIFT CTRL" direction.key "Move window to monitor ${direction.name}" "movewindow" "mon:${direction.arg}")
  ]) [
    { key = "H"; name = "left"; arg = "l"; }
    { key = "J"; name = "down"; arg = "d"; }
    { key = "K"; name = "up"; arg = "u"; }
    { key = "L"; name = "right"; arg = "r"; }
  ] ++ lib.concatMap (number: let n = toString number; in [
    (bind "SUPER" n "Go to workspace ${n}" "workspace" n)
    (bind "SUPER SHIFT" n "Move window to workspace ${n}" "movetoworkspace" n)
  ]) (lib.range 1 9) ++ map (media:
    locked "" media.key media.description "exec" "${lib.getExe pkgs.playerctl} ${media.command}"
  ) [
    { key = "XF86AudioPlay"; description = "Play or pause"; command = "play-pause"; }
    { key = "XF86AudioStop"; description = "Stop playback"; command = "stop"; }
    { key = "XF86AudioPrev"; description = "Previous track"; command = "previous"; }
    { key = "XF86AudioNext"; description = "Next track"; command = "next"; }
  ];

  labels = pkgs.writeText "hyprland-keybindings.txt" (lib.concatMapStringsSep "\n" (b:
    "${lib.optionalString (b.mods != "") "${b.mods} + "}${b.key}    ${b.description}"
  ) bindings + "\n");
  viewer = pkgs.writeShellApplication {
    name = "hyprland-keybindings";
    text = ''
      # Read-only: choosing a row never executes its associated command.
      ${lib.getExe pkgs.fuzzel} --dmenu --prompt='Keybindings: ' < ${labels} > /dev/null || true
    '';
  };
  bindingSettings = lib.genAttrs (lib.unique (map (b: b.kind) bindings)) (kind:
    map (b: "${b.mods}, ${b.key}, ${b.description}, ${b.dispatcher}, ${b.argument}")
      (builtins.filter (b: b.kind == kind) bindings)
  );
in
{
  home.packages = with pkgs; [ brightnessctl playerctl wl-clipboard fuzzel hyprpicker ];

  systemd.user.services.hyprland-polkit-agent = {
    Unit = {
      Description = "PolicyKit authentication agent for Hyprland";
      Requisite = [ "hyprland-session.target" ];
      PartOf = [ "hyprland-session.target" ];
      After = [ "hyprland-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "hyprland-session.target" ];
  };

  wayland.windowManager.hyprland = {
    enable = true;
    package = pkgs.hyprland;
    # Keep described Hyprlang bindings even on HM versions defaulting to Lua.
    configType = "hyprlang";
    xwayland.enable = true;
    systemd = {
      enable = true;
      enableXdgAutostart = false;
    };
    # HM starts/stops hyprland-session.target. Caelestia must be attached to
    # that target; DMS must be attached ONLY to niri.service in its own module,
    # not graphical-session.target (which both compositors legitimately use).
    settings = {
      env = [ "NIXOS_OZONE_WL,1" ];
      monitor = [ ",preferred,auto,1" ];
      input = {
        numlock_by_default = true;
        follow_mouse = 1;
        accel_profile = "flat";
        sensitivity = 0;
        touchpad = {
          tap-to-click = true;
          natural_scroll = true;
          scroll_factor = 0.3;
        };
      };
      general = {
        layout = "dwindle";
        gaps_in = 8;
        gaps_out = 16;
        border_size = 4;
        "col.active_border" = lib.mkForce "rgba(${config.lib.stylix.colors.base0D}cc)";
        "col.inactive_border" = lib.mkForce "rgb(${config.lib.stylix.colors.base03})";
      };
      decoration = {
        rounding = 0;
        shadow.enabled = false;
      };
      dwindle.preserve_split = true;
      misc = {
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
        mouse_move_enables_dpms = true;
        key_press_enables_dpms = true;
      };
      # Dwindle is a tree, not Niri's scrolling columns. Column consume/expel,
      # first/last, preset sizes, workspace reordering and centering visible
      # columns intentionally have no pretend equivalents. Groups are optional
      # tabbed windows; directional move bindings move ONE window, not a column.
      # Niri's floating/tiling focus toggle and shortcut-inhibitor toggle are
      # also omitted rather than substituting commands with different effects.
      # Super+Shift+Space opens Caelestia's launcher instead of system-menu:
      # that menu hardcodes DMS and Niri-specific capture operations.
      # Super+P opens the dashboard rather than DMS's control center.
      # Super+O remains unbound: Caelestia 2.5.0 has no verified overview IPC.
    } // bindingSettings;
  };
}
