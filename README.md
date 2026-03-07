# unlock

一个简单的流媒体解锁检测脚本，用来快速测试 VPS 对常见平台的访问情况。

## 当前支持

- Netflix
- YouTube Premium / Region
- Disney+
- Prime Video
- Max / HBO
- Apple TV+
- Spotify
- TikTok
- ChatGPT
- Gemini
- Claude
- Bing Search
- Google Search
- Google Play Store
- iQIYI
- Instagram Licensed Audio
- MetaAI
- OneTrust
- Paramount+
- Reddit
- SonyLiv
- Sora
- Steam Store
- TVBAnywhere+
- Viu
- Abema
- DAZN
- Bilibili
- KOCOWA

## 使用方法

### 直接运行

```bash
chmod +x stream-unlock.sh
./stream-unlock.sh
```

### 一键命令

```bash
git clone https://github.com/Spittingjiu/unlock.git && cd unlock && chmod +x stream-unlock.sh && ./stream-unlock.sh
```

### bash + curl 一键运行

直接运行最新版脚本：

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

## IPv4 / IPv6 分开测试

只测 IPv4：

```bash
./stream-unlock.sh -4
```

只测 IPv6：

```bash
./stream-unlock.sh -6
```

## 特性

- 彩色输出
- 支持 IPv4 / IPv6 分开测试
- 多平台基础检测

## 说明

- 这是基于网页/API特征的基础检测脚本
- 结果可作为参考，但不是官方级 100% 结论
- 平台风控、地区策略、返回内容变化，都可能影响检测结果

## 适用场景

- 新 VPS 到手后的快速解锁测试
- 对比不同机房/不同地区机器的流媒体表现
- 粗略判断某平台是否可用


## 输出风格

当前输出风格已调整为更接近常见流媒体检测脚本样式，例如：

```bash
Apple                     YES (Region: JPN)
Netflix                   YES (Region: JP)
MetaAI                    Unknown: unexpected response: ajax status=401, home status=403
```


## 新版补充

- 已统一常见地区格式，例如 `JP / JPN` 统一显示为 `JP`
- 已细化部分失败原因，例如 `Failed (Network Connection Failed)`、`Failed (Access Denied)`、`Failed (HTTP xxx)`
- 已补充 `TikTok Region` 与 `Spotify Registration` 的更细化检测逻辑
