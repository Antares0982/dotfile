{
  bashInteractive,
  openssh,
  replaceVars,
  stdenvNoCC,
  ...
}:
stdenvNoCC.mkDerivation {
  pname = "git-ssh-sign";
  name = "git-ssh-sign";
  script = replaceVars ./git-ssh-sign-wrapper {
    inherit bashInteractive openssh;
  };

  phases = [ "installPhase" ];

  installPhase = ''
    mkdir -p $out/bin
    cp $script $out/bin/git-ssh-sign
    chmod +x $out/bin/git-ssh-sign
  '';
}
