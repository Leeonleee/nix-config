{ ... }:

{
  # Graphical workstation services shared by desktop and framework.
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  # Support input simulation for tools such as ydotool.
  hardware.uinput.enable = true;

  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  services.printing.enable = true;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  users.users.leonl.extraGroups = [
    "ydotool"
    "input"
    "uinput"
  ];

  programs.firefox.enable = true;

  programs.ydotool = {
    enable = true;
    group = "ydotool";
  };
}
