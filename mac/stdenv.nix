{
  config,
  pkgs,
  ...
}:
let
  system-cc-shims =
    pkgs.runCommand "system-cc-shims"
      {
        preferLocalBuild = true;
        allowSubstitutes = false;
      }
      ''
            mkdir -p $out/bin
            for tool in clang clang++ cc c++ ld; do
              cat > "$out/bin/$tool" << 'SCRIPT'
        #!/bin/sh
        exec "/usr/bin/$(basename "$0")" "$@"
        SCRIPT
              chmod +x "$out/bin/$tool"
            done
      '';
in
{
  environment.extraInit = ''
    export PATH="${system-cc-shims}/bin:$PATH"
  '';
}
