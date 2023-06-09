{inputs, ...}: {
  perSystem = {
    config,
    pkgs,
    system,
    inputs',
    self',
    ...
  }: let
    devTools = [
      # rust tooling
      self'.packages.rust-toolchain
      pkgs.cargo-audit
      pkgs.cargo-udeps
      pkgs.bacon
      # version control
      pkgs.cocogitto
      # inputs'.bomper.packages.cli
      # formatting
      self'.packages.treefmt
      # misc
      pkgs.wasm-bindgen-cli
      pkgs.miniserve
    ];

    # packages required for building the rust packages
    extraPackages = [
      pkgs.pkg-config
    ];
    withExtraPackages = base: base ++ extraPackages;

    craneLib = inputs.crane.lib.${system}.overrideToolchain self'.packages.rust-toolchain;

    common-build-args = rec {
      src = inputs.nix-filter.lib {
        root = ../.;
        include = [
          "crates"
          "Cargo.toml"
          "Cargo.lock"
        ];
      };

      pname = "yew-app";

      nativeBuildInputs = withExtraPackages [];
      LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath nativeBuildInputs;
    };

    deps-only = craneLib.buildDepsOnly ({} // common-build-args);

    packages = let
      buildWasmPackage = {
        name,
        wasm-bindgen-target ? "web",
      }: let
        underscore_name = pkgs.lib.strings.replaceStrings ["-"] ["_"] name;

        cargo-derivation = craneLib.buildPackage ({
            pname = name;
            cargoArtifacts = deps-only;
            cargoExtraArgs = "-p ${name} --target wasm32-unknown-unknown";
            doCheck = false;
          }
          // common-build-args);

        wasm-derivation = pkgs.stdenv.mkDerivation {
          name = "${name}-wasm-bindgen";
          buildInputs = [pkgs.wasm-bindgen-cli];
          nativeBuildInputs = [pkgs.binaryen];
          src = "";
          buildCommand = ''
            ${pkgs.wasm-bindgen-cli}/bin/wasm-bindgen \
              ${cargo-derivation}/lib/${underscore_name}.wasm \
              --out-dir $out \
              --target ${wasm-bindgen-target} \

            ${pkgs.binaryen}/bin/wasm-opt \
              -Oz \
              --output $out/${underscore_name}_bg.wasm \
              $out/${underscore_name}_bg.wasm
          '';
        };
      in
        wasm-derivation;
    in rec {
      app = buildWasmPackage {
        name = "app";
      };

      app-static = pkgs.runCommand "bundled-server" {} ''
        mkdir -p $out

        cp -r ${../public}/* $out
        cp ${app}/* $out
      '';

      app-serve = pkgs.writeShellApplication {
        name = "app-serve";
        runtimeInputs = [pkgs.miniserve];
        text = ''
          miniserve ${app-static} "$@"
        '';
      };

      cargo-doc = craneLib.cargoDoc ({
          cargoArtifacts = deps-only;
        }
        // common-build-args);
    };

    checks = {
      clippy = craneLib.cargoClippy ({
          cargoArtifacts = deps-only;
          cargoClippyExtraArgs = "--all-features -- --deny warnings";
        }
        // common-build-args);

      rust-fmt = craneLib.cargoFmt ({
          inherit (common-build-args) src;
        }
        // common-build-args);

      rust-tests = craneLib.cargoNextest ({
          cargoArtifacts = deps-only;
          partitions = 1;
          partitionType = "count";
        }
        // common-build-args);
    };

    apps = {
      serve = {
        type = "app";
        program = pkgs.lib.getBin self'.packages.app-serve;
      };
    };
  in rec {
    inherit packages checks apps;

    devShells.default = pkgs.mkShell rec {
      packages = withExtraPackages devTools;
      LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath packages;

      shellHook = ''
        ${config.pre-commit.installationScript}
      '';
    };
  };
}
