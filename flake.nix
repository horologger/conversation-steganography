{
  description = "Conversation Stenography — Go CLI plus a local Hugging Face model backend";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = f:
        nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      devShells = forAllSystems (pkgs:
        let
          # python/hf_model.py speaks the line-delimited JSON protocol in
          # process_model.go. On Apple Silicon the project can also use
          # python/mlx_model.py, but mlx-lm is not packaged in nixpkgs, so this
          # shell always provides the Transformers backend.
          pythonEnv = pkgs.python313.withPackages (ps: with ps; [
            torch
            transformers
            huggingface-hub
          ]);
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.go
              pkgs.gopls
              pkgs.gotools
              pythonEnv
            ];

            # Read by chain.go and simulate.go, so conversation-stenography.local.json
            # does not need to hard-code a /nix/store path for the interpreter.
            CONVERSATION_STENOGRAPHY_PYTHON = "${pythonEnv}/bin/python3";

            shellHook = ''
              echo "conversation-stenography dev shell"
              echo "  go      $(go version | cut -d' ' -f3)"
              echo "  python  ${pythonEnv}/bin/python3"
              echo
              echo "Build:     go build -o conversation-stenography ./cmd/conversation-stenography"
              echo "Model:     python3 -c \"from huggingface_hub import snapshot_download as d; import os; print(os.path.realpath(d(repo_id='openai-community/gpt2')))\""
              echo "Config:    cp conversation-stenography.example.json conversation-stenography.local.json  # then set \"model\""
              echo "Run:       export CONVERSATION_STENOGRAPHY_SECRET=... && ./conversation-stenography simulate"
              echo
              echo "Do not run './conversation-stenography setup' -- it pip-installs torch into a venv, which does not work here."
            '';
          };
        });
    };
}
