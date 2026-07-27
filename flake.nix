{
  description = "NixOS configurations for the (Hetzner) cloud";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko, ... }@inputs:
  let
    userSettings = {
      username = "sakuk";
      description = "Saku Karttunen";
      email = "saku.karttunen@proton.me";
    };

    mkHost = hostname:
      nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs userSettings hostname; };
        modules = [
          ./hosts/common.nix
          ./hosts/${hostname}/configuration.nix
          disko.nixosModules.disko
        ];
      };
  in
  {
    nixosConfigurations = {
      airut = mkHost "airut";
      taurudesign = mkHost "taurudesign";
      helmiala = mkHost "helmiala";
    };
  };
}
