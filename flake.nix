{
  description = "xpmminer nixos builder with cmake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
        ncurses = pkgs.ncurses;
        cmake = pkgs.cmake;
        curl = pkgs.curl;
        jansson = pkgs.jansson;
        openssl = pkgs.openssl;
        gmp = pkgs.gmp5;
        gcc = pkgs.gcc;
        gnumake = pkgs.gnumake;
      in {
        devShell = pkgs.mkShell {
          buildInputs = [ ncurses cmake curl jansson openssl gmp gcc gnumake ];
          shellHook = ''
            echo "xpmminer nixos builder with cmake ready!"
          '';
        };

        packages.default = pkgs.stdenv.mkDerivation {
          name = "xpmminer-nixos-builder-with-cmake";
          src = ./src;
          nativeBuildInputs = [ cmake ];
          buildInputs = [ ncurses curl jansson openssl gmp gcc gnumake ];
          
          cmakeFlags = [
            "-DCMAKE_BUILD_TYPE=Release"
            "-DBUILDOPENCLMINER=OFF"
            "-DBUILDCUDAMINER=OFF"
          ];

          enableParallelBuilding = true;
          
          installPhase = ''
            mkdir -p $out
            cp -r * $out/
          '';
        };
      }
    );
}
