# The system menu's NixOS section: flake updates, rollback, firmware, garbage
# collection, generations and the plain rebuild actions. `terminal` wraps a
# shell command so it runs, and stays visible, in Kitty.
{ config, lib, pkgs, terminal }:

let
  checkout = lib.escapeShellArg "${config.home.homeDirectory}/nix-config";
  nix = "${lib.getExe pkgs.nix} --extra-experimental-features 'nix-command flakes'";
  nvd = lib.getExe pkgs.nvd;
  hostname = "${pkgs.nettools}/bin/hostname";
  profiles = "/nix/var/nix/profiles";

  rebuildCommand = mode: ''
    cd ${checkout} && sudo ${lib.getExe pkgs.nixos-rebuild} ${mode} \
      --flake ".#$(${hostname})" \
      --option experimental-features 'nix-command flakes'
  '';
  rebuild = mode: terminal (rebuildCommand mode);

  # Resolves the latest input revisions into a temporary lock file, leaving
  # the checkout untouched. `preview` also builds that system and diffs it
  # against the running one; the build is reused by a later real update.
  updates = pkgs.writeShellApplication {
    name = "nixos-updates";
    runtimeInputs = [ pkgs.jq pkgs.util-linux ];
    text = ''
      mode="''${1:-check}"
      tmp="$(mktemp -d)"
      trap 'rm -rf "$tmp"' EXIT
      cd ${checkout}

      echo "Resolving latest flake inputs…"
      ${nix} flake update --output-lock-file "$tmp/flake.lock"
      changes="$(jq -r --slurpfile new "$tmp/flake.lock" '
        def locked($lock; $name): $lock.nodes[$lock.nodes.root.inputs[$name]].locked;
        def day: if . then (todate | .[0:10]) else "?" end;
        . as $old | $old.nodes.root.inputs | keys[] as $name
        | locked($old; $name) as $a | locked($new[0]; $name) as $b
        | select(($a.rev // $a.narHash) != ($b.rev // $b.narHash))
        | "\($name)\t\($a.rev[0:7] // "?") → \($b.rev[0:7] // "?")\t\($a.lastModified | day) → \($b.lastModified | day)"
      ' flake.lock)"

      if [[ -z "$changes" ]]; then
        echo "All flake inputs are up to date."
        exit 0
      fi
      echo
      echo "Inputs with updates:"
      column -t -s $'\t' <<< "$changes"

      [[ "$mode" == preview ]] || exit 0
      host="$(${hostname})"
      echo
      echo "Building the updated $host configuration…"
      new="$(${nix} build --no-link --print-out-paths --no-write-lock-file \
        --reference-lock-file "$tmp/flake.lock" \
        ".#nixosConfigurations.$host.config.system.build.toplevel")"
      echo
      ${nvd} diff /run/current-system "$new"
    '';
  };

  # Updates flake.lock in the checkout, then applies it. The lock change is
  # left uncommitted so it can be reviewed or reverted.
  update = mode: terminal ''
    before="$(readlink -f /run/current-system)"
    cd ${checkout} || exit 1
    ${nix} flake update || exit 1
    if ! ( ${rebuildCommand mode} ); then
      echo
      echo "Rebuild failed; revert the lock with: git -C ${checkout} checkout flake.lock"
      exit 1
    fi
    echo
    ${nvd} diff "$before" /run/current-system
    echo
    git -C ${checkout} diff --stat flake.lock
    echo "flake.lock is updated but not committed."
  '';

  rollback = terminal ''
    current="$(readlink ${profiles}/system)"
    current="''${current#system-}"
    current="''${current%-link}"
    previous=""
    for link in ${profiles}/system-*-link; do
      number="''${link##*/system-}"
      number="''${number%-link}"
      (( number < current && number > ''${previous:-0} )) && previous="$number"
    done
    if [[ -z "$previous" ]]; then
      echo "No generation older than $current to roll back to."
      exit 1
    fi
    ${nvd} diff /run/current-system "${profiles}/system-$previous-link"
    echo
    read -rp "Roll back from generation $current to $previous? [y/N] " answer
    [[ "$answer" == [yY]* ]] || exit 0
    sudo ${lib.getExe pkgs.nixos-rebuild} switch --rollback
  '';

  # fwupdmgr comes from the system (services.fwupd) to match its daemon.
  # It exits with 2 when there is nothing to do.
  fwupdmgr = args: "fwupdmgr ${args} || [[ $? -eq 2 ]]";

  # Old user (Home Manager) and system generations are removed, then the
  # default system reinstalls the bootloader so stale entries disappear.
  collectGarbage = options: prompt: terminal ''
    ${lib.optionalString (prompt != null) ''
      read -rp ${lib.escapeShellArg "${prompt} [y/N] "} answer
      [[ "$answer" == [yY]* ]] || exit 0
    ''}
    df -h /nix
    echo
    nix-collect-garbage ${options} &&
      sudo nix-collect-garbage ${options} &&
      sudo ${profiles}/system/bin/switch-to-configuration boot
    echo
    df -h /nix
  '';

  # Generation pages receive the selected number as $1 via "$value".
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
in
{
  label = "NixOS";
  children = [
    {
      label = "Update";
      children = [
        { label = "Check for updates"; action = terminal (lib.getExe updates); }
        { label = "Preview updates"; action = terminal "${lib.getExe updates} preview"; }
        { label = "Update flake + test"; action = update "test"; }
        { label = "Update flake + switch"; action = update "switch"; }
      ];
    }
    { label = "Rollback"; action = rollback; }
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
            action = generation ''${nvd} diff /run/current-system "${profiles}/system-$1-link"'';
          }
        ];
      };
    }
    {
      label = "Firmware";
      children = [
        {
          label = "Check";
          action = terminal ''
            ${fwupdmgr "refresh --force"}
            ${fwupdmgr "get-updates"}
          '';
        }
        { label = "Update"; action = terminal (fwupdmgr "update"); }
      ];
    }
    {
      label = "Garbage collection";
      children = [
        { label = "Older than 7 days"; action = collectGarbage "--delete-older-than 7d" null; }
        { label = "All old generations"; action = collectGarbage "--delete-old" "Delete every generation except the current ones?"; }
      ];
    }
    {
      label = "Check configuration";
      action = terminal "cd ${checkout} && ${nix} flake check --no-build";
    }
    { label = "Build configuration"; action = rebuild "build"; }
    { label = "Test configuration (temporary)"; action = rebuild "test"; }
    { label = "Switch configuration"; action = rebuild "switch"; }
  ];
}
