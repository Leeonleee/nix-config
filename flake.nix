{
  description = "My NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager-unstable = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    stylix = {
      url = "github:danth/stylix/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niri.url = "github:sodiboo/niri-flake";

    dms = {
      url = "github:AvengeMedia/DankMaterialShell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{
    nixpkgs,
    home-manager,
    stylix,
    niri,
    ...
  }: {
    nixosConfigurations.framework = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      specialArgs = {
        inherit inputs;
      };

      modules = [
        ./hosts/framework/configuration.nix

        home-manager.nixosModules.home-manager
        stylix.nixosModules.stylix
        niri.nixosModules.niri



        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;

          home-manager.extraSpecialArgs = {
            inherit inputs;
          };

          home-manager.users.leonl = import ./home/leonl/home.nix;
        }
      ];
    };

    nixosConfigurations.desktop = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      modules = [
        ./hosts/desktop/configuration.nix

        home-manager.nixosModules.home-manager
        stylix.nixosModules.stylix

        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;

          home-manager.extraSpecialArgs = {
            inherit inputs;
          };

          home-manager.users.leonl = import ./home/leonl/home.nix;
        }
      ];
    };
  };
}
