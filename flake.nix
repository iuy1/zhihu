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
        {
          devShells.default = pkgs.mkShell {
            shellHook = pre-commit-hook.shellHook;
            packages = with pkgs; [
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
