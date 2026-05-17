{
  pkgs,
  stdenv,
  fetchzip,
  jetbrains,
  ...
}:
{
  jbPkgDef = (
    with jetbrains;
    [
      clion
      goland
      rust-rover
    ]
  );
  versionDef = {
    x86_64-linux = {
      # activation code webpage: http://jets.idejihuo.com/v3/
      clion = {
        # get the version and build number here: https://www.jetbrains.com/clion/download/other.html
        version = "2025.1.1";
        sha256 = "sha256:1icaj5jhzggqqmikm6gz7b4qmff2db6xndnpk3nna2yp81r7sx1g";
        url = "https://download.jetbrains.com/cpp/CLion-2025.1.1.tar.gz";
        buildNumber = "251.25410.104";
      };
      goland = {
        version = "2024.2";
        sha256 = "sha256:1ylccl9bbf4lq6hlqviswnyi0ks84lrx0d8g84dm0wd5p6s4vf68";
        url = "https://download.jetbrains.com/go/goland-2024.2.tar.gz";
        buildNumber = "242.20224.306";
      };
    };
  };
  # stands for plugins for every jetbrain app
  commonPlugins = [
    # plugins already defined in nixpkgs
    # "github-copilot"
    "nixidea"
  ]
  ++ [
    # plugins need mkDerivation
    (stdenv.mkDerivation {
      name = "jetbrains-plugin-13710";
      installPhase = ''
        runHook preInstall
        mkdir -p $out && cp -r . $out
        runHook postInstall
      '';
      src = fetchzip {
        executable = false;
        # download it manually and get the filename: xx.yyy.zzz.zip.
        # the yyy.zzz should be what you need.
        # also the download url should be looking like this:
        # https://plugins.jetbrains.com/plugin/download?rel=true&updateId=aaaaaa
        # the aaaaaa part is also needed.
        # sample: url = "https://plugins.jetbrains.com/files/plugin_id/updateId/zh.yyy.zzz.zip";
        url = "https://plugins.jetbrains.com/files/13710/512034/zh.241.198.zip";
        hash = "sha256-+uvQlGgI+A9o5JBnEJsYV/zjasQXWmDG15plnukC0hM=";
      };
    })
  ];
  # plugins for each IDE, e.g. additionalPlugins.clion.<plugin-name>
  additionalPlugins = { };
}
