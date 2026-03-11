# unlock

一个偏保守的流媒体 / 服务可用性检测脚本。

当前版本优先保证：

- 结果尽量基于真实检测
- 能确认可用就输出 `YES`
- 明确不解锁 / 不可用就输出 `NO`
- 不能可靠判断就输出 `UNKNOWN`
- 只有拿到可靠地区信息时，才输出 `Region`

## 当前平台

- Netflix
- Disney+
- YouTube
- Amazon Prime Video
- TikTok
- Spotify Registration
- ChatGPT
- Gemini
- Claude
- Apple
- BingSearch
- GoogleSearch
- Google Play Store
- IQiYi
- Instagram Licensed Audio
- KOCOWA
- MetaAI
- OneTrust
- Paramount+
- Reddit
- SonyLiv
- Sora
- Steam Store
- TVBAnywhere+
- Viu.com

## 一键运行

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Spittingjiu/unlock/master/stream-unlock.sh)
```

只测 IPv4：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Spittingjiu/unlock/master/stream-unlock.sh) -4
```

只测 IPv6：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Spittingjiu/unlock/master/stream-unlock.sh) -6
```

## Netflix 判定

Netflix 分为：

- `YES (Full Library / Region: XX)`
- `YES (Full Library)`
- `YES (Originals Only)`
- `NO`
- `UNKNOWN`

## 输出原则

- 真实能确认可用：`YES`
- 真实能确认不可用：`NO`
- 命中风控/挑战（如 403/429）：`BLOCKED_OR_CHALLENGED`
- 无法可靠判断：`UNKNOWN`
- 只有真实拿到地区信息时才显示 `Region`

## 新增：地区显示（Geo）

脚本启动时会先显示当前出口地区信息，例如：

```bash
IP: 1.2.3.4
Location: United States, California, Los Angeles (US)
```

地区来源优先级：`ipapi.co` -> `ipwho.is` -> `ipinfo.io/country`（兜底）。
