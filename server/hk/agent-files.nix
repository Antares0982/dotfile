{ config, lib, ... }:
let
  root = "/var/lib/agent-files";
in
{
  users.groups.agent-files = { };
  users.users.nginx.extraGroups = [ "agent-files" ];
  users.users.alice.extraGroups = [ "agent-files" ];

  systemd.tmpfiles.rules = [
    "d ${root} 0750 root agent-files - -"
    "d ${root}/outgoing 2770 nginx agent-files - -"
    "d ${root}/incoming 2770 alice agent-files - -"
    "d ${root}/tmp 2770 nginx agent-files 7d -"
  ];

  systemd.services.nginx.serviceConfig = {
    SupplementaryGroups = [ "agent-files" ];
    ReadWritePaths = [
      "${root}/outgoing"
      "${root}/tmp"
    ];
  };
  systemd.services.telegram-bot-api = lib.mkIf config.services.telegram-bot-api.enable {
    serviceConfig.SupplementaryGroups = [ "agent-files" ];
  };

  services.nginx.commonHttpConfig = ''
    limit_conn_zone $server_name zone=agent_files:1m;
  '';
  services.nginx.virtualHosts."tg.alyr.dev" = {
    forceSSL = true;
    enableACME = true;
    inherit root;
    basicAuthFile = config.age.secrets.agentFilesHtpasswd.path;
    extraConfig = ''
      client_max_body_size 2000000000;
      client_body_timeout 120s;
      send_timeout 120s;
      limit_conn agent_files 4;
      add_header Cache-Control "no-store" always;
    '';
    locations."~ \"^/outgoing/[0-9a-f]{32}$\"".extraConfig = ''
      dav_methods PUT;
      dav_access user:rw group:r;
      create_full_put_path off;
      client_body_temp_path ${root}/tmp;
      limit_except PUT { deny all; }
    '';
    locations."~ \"^/incoming/[0-9a-f]{32}$\"".extraConfig = ''
      limit_except GET { deny all; }
      try_files $uri =404;
    '';
    locations."/".return = "404";
  };
}
