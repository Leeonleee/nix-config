{ config, lib, pkgs, ... }:

let
  inherit (config.lib.formats.rasi) mkLiteral;
  cfg = config.programs.system-menu;
  capture = args: lib.escapeShellArgs ([ (lib.getExe config.programs.capture.package) ] ++ args);
  terminal = command: lib.escapeShellArgs [
    (lib.getExe config.programs.kitty.package)
    "--hold"
    (pkgs.writeShellScript "system-menu-terminal" command)
  ];
  checkout = lib.escapeShellArg "${config.home.homeDirectory}/nix-config";
  rebuild = mode: terminal ''
    cd ${checkout} && sudo ${lib.getExe pkgs.nixos-rebuild} ${mode} \
      --flake ".#$(${pkgs.nettools}/bin/hostname)" \
      --option experimental-features 'nix-command flakes'
  '';

  # Generation pages receive the selected number as $1 via "$value".
  profiles = "/nix/var/nix/profiles";
  generation = command: ''${terminal command} "$value"'';
  generations = pkgs.writeShellScript "system-menu-generations" ''
    current="$(readlink ${profiles}/system)"
    running="$(readlink -f /run/current-system)"
    booted="$(readlink -f /run/booted-system)"
    for link in ${profiles}/system-*-link; do
      [[ -e "$link" ]] || continue
      number="''${link##*/system-}"
      number="''${number%-link}"
      target="$(readlink -f "$link")"
      version="$(cat "$link/nixos-version" 2>/dev/null || echo unknown)"
      date="$(date -d "@$(stat -c %Y "$link")" '+%Y-%m-%d %H:%M')"
      flags=()
      [[ "''${link##*/}" == "$current" ]] && flags+=(default)
      [[ "$target" == "$running" ]] && flags+=(running)
      [[ "$target" == "$booted" ]] && flags+=(booted)
      label="$number  ·  $date  ·  $version"
      (( ''${#flags[@]} )) && label+="  ($(IFS=,; echo "''${flags[*]}" | sed 's/,/, /g'))"
      printf '%s\t%s\n' "$number" "$label"
    done | sort -rn
  '';

  # Each entry has either an action or children. Add children at any depth;
  # navigation/dispatch is generated below without eval or label matching.
  # A dynamic entry lists rows from a script printing "value<TAB>label"; each
  # row opens its children, whose actions read the selected row as $value.
  # Sessions add their own sections through programs.system-menu.sections,
  # keyed by XDG_CURRENT_DESKTOP; the NixOS section and commonSections are shared.
  nixosSection = {
    label = "NixOS";
    children = [
      {
        label = "Check configuration";
        action = terminal "cd ${checkout} && ${lib.getExe pkgs.nix} --extra-experimental-features 'nix-command flakes' flake check --no-build";
      }
      { label = "Build configuration"; action = rebuild "build"; }
      { label = "Test configuration (temporary)"; action = rebuild "test"; }
      { label = "Switch configuration"; action = rebuild "switch"; }
      {
        label = "Generations";
        dynamic = {
          name = "generation";
          list = generations;
          children = [
            {
              label = "Switch (make default)";
              action = generation ''
                sudo ${pkgs.nix}/bin/nix-env --profile ${profiles}/system --switch-generation "$1" &&
                  sudo ${profiles}/system/bin/switch-to-configuration switch
              '';
            }
            {
              label = "Test (temporary)";
              action = generation ''sudo "${profiles}/system-$1-link/bin/switch-to-configuration" test'';
            }
            {
              label = "Boot (next reboot)";
              action = generation ''
                sudo ${pkgs.nix}/bin/nix-env --profile ${profiles}/system --switch-generation "$1" &&
                  sudo ${profiles}/system/bin/switch-to-configuration boot
              '';
            }
            {
              label = "Show changes from running system";
              action = generation ''${lib.getExe pkgs.nvd} diff /run/current-system "${profiles}/system-$1-link"'';
            }
          ];
        };
      }
    ];
  };
  menuFor = sections: {
    label = "System";
    children = [ nixosSection ] ++ cfg.commonSections ++ sections;
  };

  # Stable IDs are passed as row metadata, independently of labels/filtering.
  # ROFI_DATA records the current page; stripping its last index goes back.
  # Dynamic rows use "<id>:<value>" pages, so back strips the value instead.
  pageHeader = data: ''
    printf '\0data\x1f%s\n' ${data}
    printf '\0no-custom\x1ftrue\n\0use-hot-keys\x1ftrue\n'
    printf '\0keep-filter\x1ffalse\n'
  '';
  backRow = label: ''
    printf '%s\0info\x1fback\x1fpermanent\x1ftrue\n' ${lib.escapeShellArg label}
  '';
  renderAction = node: ''
    # Do not hold Rofi's output pipe open while an action is running.
    (
      if ! (
        ${node.action}
      ); then
        notify-send --urgency=critical 'System menu' ${lib.escapeShellArg "Failed: ${node.label}"}
      fi
    ) </dev/null >/dev/null 2>&1 &
  '';

  renderMenu = id: node: if node ? dynamic then ''
    ${id})
      ${pageHeader (lib.escapeShellArg id)}
      ${node.dynamic.list} | while IFS=$'\t' read -r value label; do
        printf '%s\0info\x1f%s\n' "$label" ${lib.escapeShellArg "${id}:"}"$value"
      done
      ${backRow "Back"}
      ;;
    ${id}:*)
      selected="''${target#${id}:}"
      value="''${selected%%_*}"
      [[ "$value" =~ ^[A-Za-z0-9.-]+$ ]] || exit 0
      if [[ "$selected" == *_* ]]; then
        case "''${selected#*_}" in
          ${lib.concatStringsSep "\n" (lib.imap0 (index: entry: ''
            ${toString index})
              ${renderAction entry}
              ;;
          '') node.dynamic.children)}
          *) exit 0 ;;
        esac
      else
        ${pageHeader ''"$target"''}
        ${lib.concatStringsSep "\n" (lib.imap0 (index: entry: ''
          printf '%s\0info\x1f%s\n' ${lib.escapeShellArg "${entry.label} — ${node.dynamic.name} "}"$value" "$target"${lib.escapeShellArg "_${toString index}"}
        '') node.dynamic.children)}
        ${backRow "Back"}
      fi
      ;;
  '' else ''
    ${id})
      ${if node ? children then ''
        ${pageHeader (lib.escapeShellArg id)}
        ${lib.concatStringsSep "\n" (lib.imap0 (index: entry: ''
          printf '%s\0info\x1f%s\n' ${lib.escapeShellArgs [ entry.label "${id}_${toString index}" ]}
        '') node.children)}
        ${backRow (if id == "root" then "Close" else "Back")}
      '' else renderAction node}
      ;;
    ${lib.optionalString (node ? children) (lib.concatStringsSep "\n" (lib.imap0 (index: entry:
      renderMenu "${id}_${toString index}" entry
    ) node.children))}
  '';

  menuBackend = session: sections: pkgs.writeShellApplication {
    name = "system-menu-backend-${session}";
    runtimeInputs = [ pkgs.libnotify ];
    text = ''
      case "''${ROFI_RETV:-0}" in
        0) target=root ;;
        1) target="''${ROFI_INFO:-}" ;;
        10) target=back ;;
        *) exit 0 ;;
      esac
      if [[ "$target" == back ]]; then
        current="''${ROFI_DATA:-root}"
        [[ "$current" == root ]] && exit 0
        if [[ "$current" == *:* ]]; then
          target="''${current%%:*}"
        else
          target="''${current%_*}"
        fi
      fi
      case "$target" in
        ${renderMenu "root" (menuFor sections)}
        *) exit 0 ;;
      esac
    '';
  };

  systemMenu = pkgs.writeShellApplication {
    name = "system-menu";
    runtimeInputs = [ config.programs.rofi.finalPackage ];
    text = ''
      case "''${XDG_CURRENT_DESKTOP:-}" in
        ${lib.concatStrings (lib.mapAttrsToList (session: sections: ''
          ${lib.escapeShellArg session}) backend=${lib.getExe (menuBackend session sections)} ;;
        '') cfg.sections)}
        *) backend=${lib.getExe (menuBackend "default" [ ])} ;;
      esac
      exec rofi -show system -modes "system:$backend" \
        -i -kb-custom-1 'Control+h'
    '';
  };
in
{
  options.programs.system-menu = {
    package = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      description = "Rofi system menu command used by compositor keybindings.";
    };
    sections = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.attrs);
      default = { };
      description = "Menu sections per session, keyed by XDG_CURRENT_DESKTOP.";
    };
    commonSections = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      default = [ ];
      description = "Menu sections shown in every session, after the NixOS section.";
    };
  };

  config = {
    programs.system-menu.package = systemMenu;
    home.packages = [ systemMenu ];

    programs.rofi = {
      enable = true;
      # Rofi in the pinned package set supports Wayland natively.
      package = pkgs.rofi;
      extraConfig = {
        kb-row-down = "Down,Control+n,Control+j";
        kb-row-up = "Up,Control+p,Control+k";
        kb-accept-entry = "Return,KP_Enter,Control+m,Control+l";
        kb-cancel = "Escape,Control+g,Control+bracketleft";
        # Free Ctrl+h/k/l from Rofi's default editing/completion actions.
        kb-remove-char-back = "BackSpace,Shift+BackSpace";
        kb-remove-to-eol = "";
        kb-mode-complete = "";
      };
      theme = {
        window = {
          width = mkLiteral "520px";
          border = mkLiteral "2px";
          border-radius = mkLiteral "12px";
        };
        mainbox.padding = mkLiteral "12px";
        inputbar = {
          padding = mkLiteral "8px";
          children = mkLiteral "[ entry ]";
        };
        entry.placeholder = "Search…";
        listview = {
          lines = 8;
          fixed-height = true;
          scrollbar = false;
        };
        element = {
          padding = mkLiteral "10px";
          border-radius = mkLiteral "6px";
        };
      };
    };

    # Inherit the existing palette and fonts rather than duplicating them.
    stylix.targets.rofi.enable = true;

    # The selected Niri shell appends its own sections.
    programs.system-menu.sections.niri = [
      {
        label = "Capture";
        children = [
          {
            label = "Screenshot";
            children = [
              { label = "Region"; action = capture [ "screenshot" "region" ]; }
              { label = "Window"; action = capture [ "screenshot" "window" ]; }
              { label = "Screen"; action = capture [ "screenshot" "screen" ]; }
            ];
          }
          { label = "Screen recording (toggle)"; action = capture [ "record" "toggle" ]; }
          { label = "OCR region"; action = capture [ "ocr" ]; }
          { label = "Colour picker"; action = capture [ "colour" ]; }
          { label = "QR code"; action = capture [ "qr" ]; }
          {
            label = "Share latest capture";
            children = [
              {
                label = "Taildrop";
                action = ''
                  latest="$(${capture [ "latest" ]})" &&
                    ${lib.getExe config.services.dolphin-taildrop.package} "$latest"
                '';
              }
            ];
          }
        ];
      }
    ];

    programs.niri.settings.binds."Mod+Shift+Space" = {
      hotkey-overlay.title = "Open system menu";
      action.spawn = lib.getExe systemMenu;
    };
  };
}
