{ pkgs, ... }:
let
  # SSH target to probe. Adjust if you reach hk via a different host/IP.
  target = "hk.chr.fan";
  sshPort = "22";
  altPort = "443"; # nginx; control group on a different daemon than sshd
  interval = "15"; # seconds between probes
in
{
  # External layered reachability probe for the hk server.
  #
  # Runs on the (always-on) rpi5 and logs one line per cycle to journald.
  # Three independent layers let an outage be classified after the fact:
  #   - ping  -> kernel / network path reachable (ICMP)
  #   - 443   -> userspace + nginx alive (different daemon than sshd)
  #   - 22    -> sshd reachable
  # Read back with:  journalctl -u ssh-probe --since "<outage time> -5min"
  systemd.services.ssh-probe = {
    description = "Layered SSH reachability probe for hk";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    path = [
      pkgs.iputils
      pkgs.netcat
    ];
    serviceConfig = {
      Restart = "always";
      RestartSec = "10";
      DynamicUser = true;
    };
    script = ''
      while true; do
        ts=$(date -Iseconds)
        ping -c1 -W2 ${target} >/dev/null 2>&1 && p=PING_OK || p=PING_FAIL
        nc -z -w3 ${target} ${altPort} >/dev/null 2>&1 && h=${altPort}_OK || h=${altPort}_FAIL
        nc -z -w3 ${target} ${sshPort} >/dev/null 2>&1 && s=${sshPort}_OK || s=${sshPort}_FAIL
        echo "$ts $p $h $s"
        sleep ${interval}
      done
    '';
  };
}
