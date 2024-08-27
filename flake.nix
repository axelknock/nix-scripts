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

        llmContextCollector = pkgs.writeShellApplication {
          name = "llm-context-collector";
          runtimeInputs = with pkgs; [bash git gnugrep];
          text = builtins.readFile ./llm-context-collector.sh;
        };

        runServer = pkgs.writeShellApplication {
          name = "run-server";
          runtimeInputs = with pkgs; [ bash python3 ngrok jq curl ];
          text = builtins.readFile ./run-server.sh;
        };

      in
      {
        packages = {
          git-context-collector = llmContextCollector;
          run-server = runServer;
          default = llmContextCollector;
        };

        apps = {
          llm-context-collector = flake-utils.lib.mkApp {drv = llmContextCollector;};
          run-server = flake-utils.lib.mkApp {drv = runServer;};
          default = flake-utils.lib.mkApp {drv = llmContextCollector;};
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
