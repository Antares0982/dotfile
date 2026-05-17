{
  config,
  pkgs,
  lib,
  ...
}:
let
  optionalAttrs = lib.optionalAttrs;
  jnf = pkgs.callPackage ../../../common/jnf.nix { };
  jbPkgSettings = pkgs.callPackage ./_jetbrains-version.nix { };
  extraVmOpt = ''
    -javaagent:${jnf}/ja-netfilter.jar=jetbrains
    --add-opens=java.base/jdk.internal.org.objectweb.asm=ALL-UNNAMED
    --add-opens=java.base/jdk.internal.org.objectweb.asm.tree=ALL-UNNAMED
  '';
  setupJetbrainParams = (
    jbPkg:
    (jbPkg.override (oldParam: {
      vmopts = if oldParam.vmopts != null then oldParam.vmopts + " " + extraVmOpt else extraVmOpt;
    }))
  );
  versionDef = jbPkgSettings.versionDef.${pkgs.stdenv.hostPlatform.system} or { };
  setupJetbrainApps =
    jbPkg:
    setupJetbrainParams (
      (jbPkg.overrideAttrs (
        oldAttrs:
        let
          per-def = versionDef.${oldAttrs.pname};
        in
        optionalAttrs (versionDef ? ${oldAttrs.pname}) {
          src = builtins.fetchurl {
            inherit (per-def) url sha256;
          };
          inherit (per-def) version buildNumber;
        }
      ))
    );
  jbPkgs = builtins.map setupJetbrainApps jbPkgSettings.jbPkgDef;
  pkgPluginMap =
    jbPkg:
    pkgs.jetbrains.plugins.addPlugins jbPkg (
      jbPkgSettings.commonPlugins ++ (jbPkgSettings.additionalPlugins.${jbPkg.pname} or [ ])
    );
in
{
  # home.packages = (builtins.map pkgPluginMap jbPkgs);
}
