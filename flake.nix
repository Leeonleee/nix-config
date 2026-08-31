{
  description = "My NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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

    nirinit = {
      url = "github:amaanq/nirinit";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      nix-darwin,
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

      pkgsUnstableDarwin = import inputs.nixpkgs-unstable {
        system = "aarch64-darwin";
        config.allowUnfree = true;
      };

      mkHost =
        {
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
            ./hosts/${hostname}
            home-manager.nixosModules.home-manager
            stylix.nixosModules.stylix
          ]
          ++ extraModules
          ++ [
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;

              home-manager.extraSpecialArgs = {
                inherit inputs pkgsUnstable;
              };

              home-manager.users.leonl.imports = [
                ./modules/home
                ./modules/home/platforms/linux.nix
              ]
              ++ homeModules;
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

      darwinConfigurations.mac = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";

        specialArgs = {
          inherit inputs;
        };

        modules = [
          ./hosts/mac

          home-manager.darwinModules.home-manager

          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;

            home-manager.backupFileExtension = "before-home-manager";

            home-manager.extraSpecialArgs = {
              inherit inputs;
              pkgsUnstable = pkgsUnstableDarwin;
            };

            home-manager.users.leonlee.imports = [
              stylix.homeModules.stylix
              ./modules/home
              ./modules/home/platforms/macos.nix
            ];
          }
        ];
      };
    };
}
