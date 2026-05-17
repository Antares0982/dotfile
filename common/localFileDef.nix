{ username, ... }:
rec {
  inherit username;
  userhome = "/home/${username}";
  docDir = "${userhome}/Documents";
  githubDir = "${docDir}/GitHub";
  scriptDir = "${githubDir}/scripts";
  xrayConfDir = "${userhome}/.config/xray";
  xrayConfPath = "${xrayConfDir}/config.json";
  xrayConfTemplatePath = "${xrayConfDir}/xray_template.json";
  p10kConfPath = "${userhome}/.p10k.zsh";
}
