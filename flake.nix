{
  description = "Canon MG2500-only printer driver";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { self, nixpkgs }: {
    packages = nixpkgs.lib.genAttrs [ "x86_64-linux" "i686-linux" ] (system:
      let pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
      in rec {
        cnijfilter-mg2500 = pkgs.callPackage ./package.nix { };
        default = cnijfilter-mg2500;
      });
    overlays.default = final: prev: {
      cnijfilter-mg2500 = final.callPackage ./package.nix { };
    };
  };
}
