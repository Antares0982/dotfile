---
name: xray-switch
description: 管理 rpi5 的 Mihomo 代理，按请求测速、选择 JP 节点、更新订阅或重启。名称保留以兼容旧技能入口。
---

# Mihomo 节点管理

本机已迁移到 Mihomo；不再调用 xs、xray-speed-test 或旧 xray-trigger。
唯一配置源是 Antares0982/dotfile 的 modules/mihomo.nix 和 resource/mihomo-tools.py。

所有沙箱操作通过宿主 worker：

```sh
mihomoctl --via-worker status
mihomo-speed-test --via-worker --refresh JP
mihomoctl --via-worker select JP '节点完整名称'
mihomoctl --via-worker update
mihomoctl --via-worker restart
```

测速仅报告带宽，不修改正式出口。只在用户要求切换时选择节点；未指定节点时，
从本次成功测速的 results 中选取，按 bytes_per_second 降序排列。
“换一个”须排除当前节点，“最快”允许保留当前节点。
命令必须成功退出、version 为 1 且 results 非空；超时或失败不能使用旧结果。
缓存有效期 600 秒，用户要求重新测试时加 --refresh。

节点名称必须取自 status 或本次测速结果。worker 只允许 JP 组，不扩大地区范围。
订阅变化导致节点消失时，重新查询或测速一次；仍失败就报告并保留现状。
worker 切换后会检查出口；成功结果包含 ip 和 country，失败时尝试恢复先前节点。
指定节点后重新查询 status；若需要独立复核，可在允许访问代理的环境中执行：

```sh
curl --noproxy '' --proxy http://127.0.0.1:1081 --max-time 20 https://www.cloudflare.com/cdn-cgi/trace
```

沙箱若不能连接 localhost，使用 worker 返回的出口验证结果，不绕过沙箱。
宿主 1081 同时支持 HTTP/SOCKS5，国内直连、其余 JP；1082 跟随 GLOBAL（RPi 默认 JP）；1083 直连。
不直接编辑私有配置、不读取 API 密钥，也不直接运行 systemctl。
请求通过客户端投递到 .agent/mihomo；不要手工拼接队列文件。
