ip46tables -A nixos-fw -p tcp -m connmark --mark 0x4d47 -m conntrack --ctstate DNAT -j nixos-fw-accept
if iptables -t mangle -S nixos-fw-rpfilter >/dev/null 2>&1; then
	ip46tables -t mangle -I nixos-fw-rpfilter -i mihomo0 -m connmark --mark 0x4d47 -m conntrack --ctdir REPLY -j RETURN
fi
