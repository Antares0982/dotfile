{ config, ... }:
{
  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        "workgroup" = "WORKGROUP";
        "server string" = "smbpc";
        "netbios name" = "smbpc";
        "hosts allow" = "192.168.0. 127.0.0.1 localhost";
        "hosts deny" = "0.0.0.0/0";
      };
      public = {
        "path" = "/home/antares/Videos";
        "browseable" = "yes";
        "read only" = "yes";
      };
    };
  };
}
