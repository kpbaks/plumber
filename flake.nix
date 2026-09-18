{
  description = "CI/CD security scanner for GitLab CI and GitHub Actions";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      perSystem =
        {
          lib,
          pkgs,
          self',
          ...
        }:
        {
          devShells.default = pkgs.mkShell {
            inputsFrom = [ self'.packages.default ];
          };

          packages.default =
            let
              fromYAML =
                file:
                lib.pipe file [
                  (it: pkgs.runCommand "converted-yaml.json" { } ''${lib.getExe pkgs.yj} < ${it} > "$out"'')
                  builtins.readFile
                  builtins.fromJSON
                ];
              action = fromYAML ./action.yml;
              # e.g. "v0.7.16" -> "0.7.16"
              removeVersionPrefix = semverLike: builtins.substring 1 (lib.stringLength semverLike) semverLike;
              version = removeVersionPrefix action.inputs.version.default;
            in

            pkgs.buildGoModule (finalAttrs: {
              pname = "plumber";
              inherit version;
              __structuredAttrs = true;

              src = ./.;

              vendorHash = "sha256-Wd0XwmZn60CDy5eg6gs7RF1jjmm5TLB+wsMjSQS2eZo=";

              ldflags = [
                "-s"
                # TODO: is this variable still read?
                "-X github.com/getplumber/plumber/cmd.Version=${finalAttrs.version}"
                # FIXME: get current rev
                # "-X github.com/getplumber/plumber/cmd.Commit=${finalAttrs.src.rev}"
                # BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
                "-X github.com/getplumber/plumber/cmd.BuildDate=1970-01-01T00:00:00Z"
              ];

              nativeBuildInputs = [ pkgs.installShellFiles ];

              postInstall = pkgs.lib.optionalString (pkgs.stdenv.buildPlatform.canExecute pkgs.stdenv.hostPlatform) ''
                installShellCompletion --cmd plumber \
                  --bash <($out/bin/plumber completion bash) \
                  --fish <($out/bin/plumber completion fish) \
                  --zsh <($out/bin/plumber completion zsh)
              '';

              nativeInstallCheckInputs = [ pkgs.versionCheckHook ];
              doInstallCheck = true;
              versionCheckProgramArg = "version";

              meta = {
                description = "Plumber detects CI/CD security issues in your GitHub workflows and gives you a score";
                homepage = "https://getplumber.io/docs/cli";
                downloadPage = "https://github.com/getplumber/plumber";
                license = pkgs.lib.licenses.mpl20;
                maintainers = with pkgs.lib.maintainers; [ kpbaks ];
                mainProgram = "plumber";
              };

            });
        };
    };
}
