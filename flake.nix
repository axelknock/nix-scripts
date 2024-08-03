{
  description = "A flake for git context collector and Python HTTP server with ngrok";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
          };
        };

        gitContextCollector = pkgs.writeShellApplication {
          name = "git-context-collector";
          runtimeInputs = with pkgs; [ bash git gnugrep ];
          text = builtins.readFile ./git-context-collector.sh;
        };

        runServer = pkgs.writeShellApplication {
          name = "run-server";
          runtimeInputs = with pkgs; [ bash python3 ngrok jq curl ];
          text = builtins.readFile ./run-server.sh;
        };

      in
      {
        packages = {
          git-context-collector = gitContextCollector;
          run-server = runServer;
          default = gitContextCollector;
        };

        apps = {
          git-context-collector = flake-utils.lib.mkApp { drv = gitContextCollector; };
          run-server = flake-utils.lib.mkApp { drv = runServer; };
          default = flake-utils.lib.mkApp { drv = gitContextCollector; };
        };

        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [
            bash
            git
            gnugrep
            python3
            ngrok
            jq
            curl
          ];
        };
      }
    );
}
