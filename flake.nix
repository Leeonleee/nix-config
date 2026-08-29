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

    openwhispr.url = "github:OpenWhispr/openwhispr";
  };

  outputs = inputs@{
    nixpkgs,
    home-manager,
    stylix,
    niri,
    ...
  }:
  let
    system = "x86_64-linux";

    pkgsUnstable = import inputs.nixpkgs-unstable {
      inherit system;
      config.allowUnfree = true;
    };

    mkHost = {
      hostname,
      extraModules ? [ ],
      homeModules ? [ ],
    }:
      nixpkgs.lib.nixosSystem {
        inherit system;

        specialArgs = {
          inherit inputs pkgsUnstable;
        };

        modules = [
          ./hosts/${hostname}/configuration.nix
          home-manager.nixosModules.home-manager
          stylix.nixosModules.stylix
        ] ++ extraModules ++ [
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;

            home-manager.extraSpecialArgs = {
              inherit inputs pkgsUnstable;
            };

            home-manager.users.leonl.imports =
              [ ./modules/home/common.nix ] ++ homeModules;
          }
        ];
      };
  in
  {
    nixosConfigurations = {
      desktop = mkHost {
        hostname = "desktop";
      };

      framework = mkHost {
        hostname = "framework";

        extraModules = [
          niri.nixosModules.niri
        ];

        homeModules = [
          ./modules/home/profiles/niri.nix
        ];
      };
    };
  };
}
