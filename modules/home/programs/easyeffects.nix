{ ... }:

let
  band = frequency: gain: q: {
    inherit frequency gain q;
    mode = "RLC (BT)";
    mute = false;
    slope = "x1";
    solo = false;
    type = "Bell";
  };

  speakerBands = {
    band0 = band 420.0 (-5.15) 4.0;
    band1 = band 360.0 (-7.72) 4.0;
    band2 = band 480.0 (-8.75) 4.0;
    band3 = band 450.0 (-4.53) 8.0;
  };
in
{
  services.easyeffects = {
    enable = true;

    # Associate this preset with the built-in speakers using the UI's autoload
    # settings rather than loading it globally (which would affect headphones).
    extraPresets.framework-speakers.output = {
      blocklist = [ ];
      plugins_order = [ "equalizer#0" ];
      "equalizer#0" = {
        bypass = false;
        input-gain = 0.0;
        output-gain = 0.0;
        mode = "IIR";
        num-bands = 4;
        split-channels = false;
        left = speakerBands;
        right = speakerBands;
      };
    };
  };
}
