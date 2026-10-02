{
  description = "my zhihu posts";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    {
      nixpkgs,
      flake-parts,
      git-hooks,
      ...
    }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      perSystem =
        { system, pkgs, ... }:
        let
          pre-commit-hook = git-hooks.lib.${system}.run {
            src = ./.;
            package = pkgs.prek;
            hooks = {
              nixfmt.enable = true;
              rumdl.enable = true;
            };
          };
        in
        rec {
          packages.zhihu-cli = pkgs.python3Packages.buildPythonApplication {
            pname = "zhihu-cli";
            version = "0.2.4";
            pyproject = true;
            src = pkgs.fetchFromGitHub {
              owner = "BAIGUANGMEI";
              repo = "zhihu-cli";
              rev = "8e32b99e1883eaa0842653993618937a262817b6";
              hash = "sha256-JqZAguqeK0yGudO7dVaiZ353v+5JKU4u3Bo6wqhuuB4=";
            };
            build-system = with pkgs.python3Packages; [
              hatchling
            ];
            dependencies = with pkgs.python3Packages; [
              click
              pillow
              qrcode
              requests
              rich
            ];
            meta = {
              description = "知乎命令行工具";
              homepage = "https://github.com/BAIGUANGMEI/zhihu-cli";
              license = pkgs.lib.licenses.asl20;
            };
          };
          devShells.default = pkgs.mkShell {
            shellHook = pre-commit-hook.shellHook;
            packages = with pkgs; [
              packages.zhihu-cli
              typst
              typstyle
              tinymist
              watchexec
            ];
          };
          formatter = pkgs.writeScriptBin "prek-formater" ''
            #!${pkgs.stdenvNoCC.shell}
            ${pkgs.lib.getExe pre-commit-hook.config.package} run --all-files \
              --config ${pre-commit-hook.config.configFile}
          '';
          checks.pre-commit-hook = pre-commit-hook;
        };
    };
}
