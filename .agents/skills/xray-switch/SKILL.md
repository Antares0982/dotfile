---
name: xray-switch
description: 管理 rpi5 的 Xray 代理；按地区测速并切换节点，或执行指定节点切换、重启和订阅更新。测速使用普通 agent 用户的宿主 worker，切换使用现有 root helper。
---

# Xray 测速与节点管理

唯一真相源是 `Antares0982/dotfile` 的 `rpi/xray.nix`、`packages/xray-speed-test.nix` 和 `resource/xray-speed-test.py`。此技能的可部署副本随仓库保存在 `.agents/skills/xray-switch/`；工作区安装位置为 `.agents/skills/xray-switch/`。

## 权限与入口

- 不运行 `xs`：它会修改生效链接并调用 sudo/systemctl，不适用于 agent 沙箱。
- 不直接调用 systemctl，也不直接修改 `/var/lib/xray`。
- `xray-speed-test FILTER` 是纯测速命令；在普通宿主用户的正常网络环境中使用。
- **在 agent 沙箱内使用 `xray-speed-test --via-worker -- FILTER`**。沙箱网络不能用来直接连接各节点；宿主 worker 以 `agent:agent` 运行，读取订阅并将 JSON 结果交回工作区。它不切换节点、不重启服务。
- 请求及结果目录为 `/home/agent/agent_work/.agent/xray-speed-test/`。通过客户端提交，不手工拼接协议文件。
- 切换触发目录为 `/home/agent/agent_work/.agent/xray-trigger/`。不要删除目录，也不要 cd 进去。

## 按测速结果切换

1. 用 `readlink /var/lib/xray/subscriptions/active.json` 记录当前节点。节点文件名含空格，所有路径必须引用。
2. 用户点名具体节点时直接使用该节点，跳到第 5 步。否则按用户指定地区筛选；未指定地区默认 `Japan`。筛选是区分大小写的文件名**字面子串**，空字符串代表所有节点。不要擅自扩大到其他地区。
3. 请求测速，将标准输出保存到工作区临时结果文件，例如：

   ```bash
   xray-speed-test --via-worker -- Japan > /home/agent/agent_work/.agent/xray-speed-result.json
   ```

   用户明确要求重新测速时加 `--refresh`。不要把超时或失败后留下的旧文件当作结果；必须同时检查本次命令退出码、JSON `version == 2` 及非空 `results`。
4. `results` 已按复测的 `bytes_per_second` 降序排列，从第一名开始选。用户要求“换个节点”时排除当前节点；用户要求“切到最快”时允许最佳节点已是当前节点，此时报告测速和当前排名，无需重启。指定排除项只影响本次选择；文件名尾部数字没有已知优先级含义。不要自行排除 IPv6：以实测成功为准。无有效候选时保留当前节点并报告，不随机切换。
5. 确认 `/var/lib/xray/subscriptions/<节点文件名>` 仍存在、是普通文件且非软链；拒绝包含 `/` 的名字及 `active.json`。若订阅已变化使目标消失，重新测速一次；再次失效则停止。
6. 只投递一个触发文件：

   ```bash
   touch "/home/agent/agent_work/.agent/xray-trigger/switch:<节点文件名>"
   ```

7. 轮询 `active.json`，最多等待 15 秒。切换 helper 会在重启失败时恢复原链接；触发文件消失并不证明成功。再通过 `curl -fsS --max-time 10 https://ipinfo.io/json` 验证出口连通性；重启期间短暂失败可隔 2 秒重试，总计最多三次。

出口国家与节点名可作为地区选择的佐证。入口服务器地址可能是中转，不要求与出口 IP 相同；城市和运营商也不是成功与否的判据。若链接已切换但出口检查持续失败，报告“切换后连通性未确认”，不要连续换节点或声称服务健康。

## 测速行为与耗时

先对所有候选串行采样最多 3 秒，再对初测前三名各采样最多 5 秒，连接超时 2 秒。最终排名仅包含复测成功节点；HTTP 200、有数据的完整下载或至少有 1 秒传输时间的超时下载才有效。

16 个候选的下载预算为 63 秒，另加 Xray 启动和清理。客户端每 10 秒报告等待状态，自行计算等待期限。命令超时、worker 不存在或测速全部失败时停止，不修改代理。worker 尚未部署时明确报告需要部署该 PR，不能直接运行 xs 绕过。

成功缓存保留 600 秒，按订阅内容、目录、筛选条件、URL 和参数区分。worker 缓存在工作区的 `.agent/xray-speed-test/cache/`，不依赖旧 `/var/lib/xray/speed_test.json`。JSON 中 `quick` 和 `final` 包含样本、失败信息及各样本 `wall_seconds`，顶层 `wall_seconds` 为完整测速耗时，`cached` 表示是否复用了缓存。

## 重启与订阅更新

用户请求重启或更新订阅时分别投递：

```bash
touch /home/agent/agent_work/.agent/xray-trigger/restart
touch /home/agent/agent_work/.agent/xray-trigger/update
```

动作异步执行；检查节点文件变化及出口连通性，不使用沙箱内的 systemctl。更新后检查 `active.json` 是否仍指向有效文件，失效时按上述测速流程选择节点。文件内容不参与旧 trigger 协议；文件名才是指令。
