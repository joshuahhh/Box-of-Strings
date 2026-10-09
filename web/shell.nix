# Build environment for the web version: GHC's JavaScript backend (plus the
# Emscripten toolchain it uses), from a pinned nixpkgs so that builds are
# reproducible and the compiler comes pre-built from cache.nixos.org.
#
#   nix-shell web/shell.nix --run web/build.sh
let
  nixpkgs = fetchTarball {
    # nixos-unstable, nixpkgs commit e7439b6b14ad3cc35d05608ebca9bce01a25f5f8
    url = "https://releases.nixos.org/nixos/unstable/nixos-26.11pre1087755.e7439b6b14ad/nixexprs.tar.xz";
    sha256 = "1k5f9ynqi0bnnf7c1f0cpnwb32nz0xa0sp6qbnn609whqnrpy5l1";
  };
  pkgs = import nixpkgs { config = { }; overlays = [ ]; };
  js = pkgs.pkgsCross.ghcjs;
  # GHC 9.10 targeting JavaScript: provides javascript-unknown-ghcjs-ghc.
  # (Added via PATH rather than `packages`, which would pick the native GHC.)
  ghcjs = js.haskellPackages.ghc;
in
pkgs.mkShell {
  packages = [ pkgs.python3 ];
  shellHook = ''
    export PATH=${ghcjs}/bin:${js.buildPackages.emscripten}/bin:$PATH
  '';
}
