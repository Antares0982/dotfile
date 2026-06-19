{ ... }:
{
  # Persist CPU / load / network activity to disk so that, after an SSH
  # outage, the resource state at the outage timestamp can be inspected.
  # Data lands in /var/log/sa/saNN (NN = day of month) and is read with `sar`.
  services.sysstat = {
    enable = true;
    # Sample once per minute instead of the default every 10 minutes, so
    # short intermittent spikes are not averaged away.
    collect-frequency = "*:00/01";
    # "<interval> <count>" passed to sadc; 1 second single sample per run.
    collect-args = "1 1";
  };
}
