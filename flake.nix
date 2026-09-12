{
  description = "My NixOS configuration";

  nixConfig = {
    extra-substituters = [
      "https://cache.numtide.com"
    ];
    extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.1.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

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

    nixvim.url = "github:nix-community/nixvim/nixos-26.05";

    stylix = {
      url = "github:danth/stylix/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niri.url = "github:sodiboo/niri-flake";

    dms = {
      url = "github:AvengeMedia/DankMaterialShell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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
      lanzaboote,
      ...
    }:
    let
      system = "x86_64-linux";

      pkgsUnstable = import inputs.nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };

      pkgsMaster = import inputs.nixpkgs-master {
        inherit system;
        config.allowUnfree = true;
      };

      pkgsUnstableDarwin = import inputs.nixpkgs-unstable {
        system = "aarch64-darwin";
        config.allowUnfree = true;
      };

      pkgsMasterDarwin = import inputs.nixpkgs-master {
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
                inherit inputs pkgsUnstable pkgsMaster;
              };

              # Packages shared by every host live in ./modules/home.
              # Host-specific Home Manager settings live in ./hosts/<hostname>/home.nix.
              home-manager.users.leonl.imports = [
                ./modules/home
                ./modules/home/platforms/linux.nix
                ./hosts/${hostname}/home.nix
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

          extraModules = [
            lanzaboote.nixosModules.lanzaboote
            niri.nixosModules.niri
          ];

          homeModules = [
            ./modules/home/profiles/niri.nix
          ];
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

	dev-nix = mkHost {
	    hostname = "dev-nix";
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
              pkgsMaster = pkgsMasterDarwin;
            };

            home-manager.users.leonlee.imports = [
              stylix.homeModules.stylix
              ./modules/home
              ./modules/home/platforms/macos.nix
              ./hosts/mac/home.nix
            ];
          }
        ];
      };
    };
}
