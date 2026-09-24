{ config, lib, pkgs, ... }:

let
  capture = lib.getExe config.programs.capture.package;
  # Noctalia equivalents of the DMS voxtypeStatus and recordingStatus bar
  # plugins (dms-voxtype.nix and dms-recording.nix), with the same polling,
  # states and click-to-stop behaviour.
  manifest = (pkgs.formats.toml { }).generate "plugin.toml" {
    id = "leonl/status";
    name = "Status indicators";
    version = "1.0.0";
    # 24 adds runAsync argument arrays.
    plugin_api = 24;
    author = "leonl";
    description = "Voxtype and screen recording status";
    widget = [
      { id = "voxtype"; entry = "voxtype.luau"; }
      { id = "recording"; entry = "recording.luau"; }
    ];
  };
  voxtype = pkgs.writeText "voxtype.luau" ''
    local looks = {
      recording = { glyph = "microphone-filled", color = "error" },
      transcribing = { glyph = "hourglass-high", color = "primary" },
      idle = { glyph = "microphone", color = "on_surface" },
      stopped = { glyph = "microphone-off", color = "on_surface" },
    }
    local state = "stopped"
    local polling = false

    local function render()
      local look = looks[state] or looks.stopped
      barWidget.setGlyph(look.glyph)
      barWidget.setGlyphColor(look.color)
      barWidget.setTooltip("Voxtype: " .. state)
      -- Only shown while listening or transcribing.
      barWidget.setVisible(state == "recording" or state == "transcribing")
    end

    render()
    noctalia.setUpdateInterval(500)

    -- Poll the daemon-aware status command rather than trusting a stale state file.
    function update()
      if polling then
        return
      end
      polling = noctalia.runAsync({ "${lib.getExe pkgs.voxtype}", "status", "--format", "json" }, function(result)
        polling = false
        local ok, status = pcall(noctalia.json.decode, result.stdout)
        state = result.exitCode == 0 and ok and type(status) == "table" and status.class or "stopped"
        render()
      end)
    end
  '';
  recording = pkgs.writeText "recording.luau" ''
    local validStates = {
      idle = true, starting = true, recording = true, stopping = true, failed = true, unavailable = true,
    }
    local state = "idle"
    local elapsed = 0
    local polling = false
    local stopping = false

    local function active()
      return state == "starting" or state == "recording" or state == "stopping"
    end

    local function render()
      local label
      if stopping or state == "stopping" then
        label = "Stopping…"
      elseif state == "recording" then
        label = string.format("Recording %02d:%02d", elapsed // 60, elapsed % 60)
      elseif state == "starting" then
        label = "Starting…"
      elseif state == "failed" then
        label = "Recording failed"
      else
        label = "Recording status unavailable"
      end
      if state == "recording" and not stopping then
        barWidget.setGlyph("player-record-filled")
        barWidget.setGlyphColor("error")
      elseif state == "failed" or state == "unavailable" then
        barWidget.setGlyph("video-off")
        barWidget.setGlyphColor("on_surface_variant")
      else
        barWidget.setGlyph("hourglass-high")
        barWidget.setGlyphColor("on_surface_variant")
      end
      barWidget.setText(label)
      -- Keep polling while hidden so a recording started by a keybinding appears.
      barWidget.setVisible(state ~= "idle")
    end

    local function markUnavailable()
      elapsed = 0
      state = "unavailable"
    end

    render()
    noctalia.setUpdateInterval(500)

    function update()
      if polling then
        return
      end
      -- Bound hung queries as well as guarding against overlapping polls.
      polling = noctalia.runAsync({
        "${lib.getExe' pkgs.coreutils "timeout"}", "--kill-after=1s", "3s", "${capture}", "record", "status",
      }, function(result)
        polling = false
        local ok, status = pcall(noctalia.json.decode, result.stdout)
        if result.exitCode ~= 0 or not ok or type(status) ~= "table" or not validStates[status.state]
            or type(status.elapsed) ~= "number" or status.elapsed < 0 or status.elapsed % 1 ~= 0 then
          if result.stderr ~= "" then
            noctalia.log("Capture status: " .. result.stderr)
          end
          markUnavailable()
        else
          elapsed = status.elapsed
          state = status.state
        end
        render()
      end)
    end

    -- Never start recording from the widget, including after a failed status query.
    function onClick()
      if stopping or not (active() or state == "failed") then
        return
      end
      stopping = true
      render()
      noctalia.runAsync({ "${capture}", "record", "stop" }, function(result)
        stopping = false
        if result.exitCode ~= 0 then
          state = "failed"
        end
        render()
      end)
    end
  '';
  plugins = pkgs.runCommand "noctalia-status-plugins" { } ''
    mkdir -p "$out/status"
    cp ${manifest} "$out/status/plugin.toml"
    cp ${voxtype} "$out/status/voxtype.luau"
    cp ${recording} "$out/status/recording.luau"
  '';
in
{
  programs.noctalia.settings = {
    plugins = {
      enabled = [ "leonl/status" ];
      # A path source is read-only, so plugins stay in the Nix store.
      source = [
        {
          name = "nix";
          kind = "path";
          location = "${plugins}";
          enabled = true;
        }
      ];
    };

    widget = {
      voxtype.type = "leonl/status:voxtype";
      recording.type = "leonl/status:recording";
    };
  };
}
