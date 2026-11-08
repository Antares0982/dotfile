{ username, ... }:
rec {
  inherit username;
  userhome = "/home/${username}";
  docDir = "${userhome}/Documents";
  githubDir = "${docDir}/GitHub";
  scriptDir = "${githubDir}/scripts";
}
