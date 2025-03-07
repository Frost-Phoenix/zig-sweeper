{
  description = "Zig project flake";

  inputs = {
    zig2nix.url = "github:Cloudef/zig2nix";
    zls.url = "github:zigtools/zls?ref=0.13.0";

    treefmt-nix.url = "github:numtide/treefmt-nix";
    zigimports.url = "github:frost-phoenix/zigimports";
  };

  outputs =
    {
      zig2nix,
      zls,
      treefmt-nix,
      zigimports,
      ...
    }:
    let
      flake-utils = zig2nix.inputs.flake-utils;
    in
    (flake-utils.lib.eachDefaultSystem (
      system:
      let
        zlsPkg = zls.packages.${system}.default;

        # Zig flake helper
        # Check the flake.nix in zig2nix project for more options:
        # <https://github.com/Cloudef/zig2nix/blob/master/flake.nix>
        env = zig2nix.outputs.zig-env.${system} {
          zig = zig2nix.outputs.packages.${system}.zig."0.13.0".bin;

          enableWayland = true;
          enableX11 = true;
          enableOpenGL = true;
          enableAlsa = true;

          customRuntimeDeps = with env.pkgs; [ ];
        };
        system-triple = env.lib.zigTripleFromString system;

        nativeBuildInputs = with env.pkgs; [ zig ];

        buildInputs = with env.pkgs; [
          libGL
          glfw-wayland
          libxkbcommon

          # X11 dependencies
          xorg.libX11
          xorg.libX11.dev
          xorg.libXcursor
          xorg.libXi
          xorg.libXinerama
          xorg.libXrandr

          # Wayland
          wayland.dev
        ];

        treefmtEval = treefmt-nix.lib.evalModule env.pkgs ./treefmt.nix;
        zigimportsPkg = zigimports.outputs.packages.${system}.default;
      in
      with builtins;
      with env.lib;
      with env.pkgs.lib;
      rec {
        # nix build .#target.{zig-target}
        # e.g. nix build .#target.x86_64-linux-gnu
        packages.target = genAttrs allTargetTriples (
          target:
          env.packageForTarget target {
            src = cleanSource ./.;

            nativeBuildInputs = nativeBuildInputs;
            buildInputs = buildInputs;
          }
        );

        # nix build .
        packages.default = packages.target.${system-triple};

        # nix run .
        apps.default =
          let
            pkg = packages.target.${system-triple};
          in
          {
            type = "app";
            program = "${pkg}/bin/zig-sweeper";
          };

        # nix run .#zon2json-lock
        apps.zon2json-lock = env.app [ env.zon2json-lock ] "zon2json-lock \"$@\"";

        formatter = treefmtEval.config.build.wrapper;

        # nix develop
        devShells.default = env.mkShell {
          buildInputs = buildInputs;
          nativeBuildInputs = [
            zlsPkg
            zigimportsPkg
          ] ++ nativeBuildInputs;

          LD_LIBRARY_PATH = env.pkgs.lib.makeLibraryPath (with env.pkgs; [ wayland ]);
        };
      }
    ));
}
