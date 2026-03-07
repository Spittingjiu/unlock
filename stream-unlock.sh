#!/usr/bin/env bash
set -euo pipefail

UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122 Safari/537.36"
IP_MODE="all"
if [[ "${1:-}" == "-4" ]]; then IP_MODE="4"; fi
if [[ "${1:-}" == "-6" ]]; then IP_MODE="6"; fi

C_RESET='\033[0m'; C_GREEN='\033[32m'; C_RED='\033[31m'; C_YELLOW='\033[33m'; C_BLUE='\033[34m'
curl_ip_flag=()
[[ "$IP_MODE" == "4" ]] && curl_ip_flag=(-4)
[[ "$IP_MODE" == "6" ]] && curl_ip_flag=(-6)

say(){ printf "%-18s %b%s%b\n" "$1" "$2" "$3" "$C_RESET"; }
fetch(){ curl "${curl_ip_flag[@]}" -A "$UA" -sL --max-time 12 "$@"; }
head_code(){ curl "${curl_ip_flag[@]}" -A "$UA" -sL -o /dev/null -w '%{http_code}' --max-time 15 "$1" || true; }
country_fallback(){ fetch https://ipinfo.io/country 2>/dev/null | tr -d '\r\n'; }
ok(){ say "$1" "$C_GREEN" "$2"; }
no(){ say "$1" "$C_RED" "$2"; }
maybe(){ say "$1" "$C_YELLOW" "$2"; }
cc(){ country_fallback | tr '[:upper:]' '[:lower:]'; }

simple_200(){ local name="$1" url="$2"; local code; code="$(head_code "$url")"; [[ "$code" == "200" ]] && ok "$name" "yes ($(cc))" || no "$name" "no"; }
simple_200_403(){ local name="$1" url="$2"; local code; code="$(head_code "$url")"; [[ "$code" == "200" || "$code" == "403" ]] && ok "$name" "yes ($(cc))" || no "$name" "no"; }

# existing
netflix(){ local code html region; code="$(head_code https://www.netflix.com/title/81280792)"; html="$(fetch https://www.netflix.com/ || true)"; region="$(printf "%s" "$html" | grep -o '"countryCode":"[A-Z][A-Z]"' | head -1 | cut -d'"' -f4 || true)"; [[ "$code" == "200" ]] && ok "Netflix" "yes (${region:-$(cc)})" || [[ "$code" == "403" || "$code" == "404" ]] && no "Netflix" "no" || maybe "Netflix" "maybe (${region:-unknown})"; }
youtube(){ local html region; html="$(fetch https://www.youtube.com/premium || true)"; region="$(printf "%s" "$html" | grep -o 'countryCode\":\"[A-Z][A-Z]' | head -1 | awk -F'"' '{print $3}' || true)"; printf "%s" "$html" | grep -qi "YouTube and YouTube Music ad-free" && ok "YouTube" "yes (${region:-$(cc)})" || no "YouTube" "no"; }
disney(){ local html region; html="$(fetch https://www.disneyplus.com/ || true)"; region="$(printf "%s" "$html" | grep -o '"countryCode":"[A-Z][A-Z]"' | head -1 | cut -d'"' -f4 || true)"; printf "%s" "$html" | grep -qiE "disney\+|stream now" && ok "Disney+" "yes (${region:-$(cc)})" || no "Disney+" "no"; }
prime(){ simple_200 "PrimeVideo" "https://www.primevideo.com/"; }
hbo(){ simple_200 "Max/HBO" "https://play.max.com/"; }
apple(){ simple_200 "AppleTV+" "https://tv.apple.com/"; }
spotify(){ simple_200 "Spotify" "https://open.spotify.com/"; }
tiktok(){ simple_200 "TikTok" "https://www.tiktok.com/"; }
chatgpt(){ simple_200_403 "ChatGPT" "https://chatgpt.com/"; }
gemini(){ simple_200_403 "Gemini" "https://gemini.google.com/"; }
abema(){ simple_200 "Abema" "https://abema.tv/"; }
dazn(){ simple_200 "DAZN" "https://www.dazn.com/"; }
bilibili(){ local code; code="$(head_code https://api.bilibili.com/x/web-interface/nav)"; [[ "$code" == "200" ]] && ok "Bilibili" "yes (cn/global)" || no "Bilibili" "no"; }

# newly added
bing_search(){ simple_200 "BingSearch" "https://www.bing.com/"; }
google_search(){ simple_200 "GoogleSearch" "https://www.google.com/"; }
google_play(){ simple_200 "GooglePlay" "https://play.google.com/store"; }
claude(){ simple_200_403 "Claude" "https://claude.ai/"; }
one_trust(){ simple_200 "OneTrust" "https://www.onetrust.com/"; }
steam_store(){ simple_200 "SteamStore" "https://store.steampowered.com/"; }
reddit(){ simple_200 "Reddit" "https://www.reddit.com/"; }
iqiyi(){ simple_200 "iQIYI" "https://www.iq.com/"; }
instagram_audio(){ simple_200 "InstagramAudio" "https://www.instagram.com/"; }
paramount(){ simple_200 "Paramount+" "https://www.paramountplus.com/"; }
sonyliv(){ simple_200 "SonyLiv" "https://www.sonyliv.com/"; }
sora(){ simple_200_403 "Sora" "https://sora.com/"; }
viu(){ simple_200 "Viu" "https://www.viu.com/"; }
metaai(){ local a b; a="$(head_code https://www.meta.ai/)"; b="$(head_code https://www.meta.ai/api/ || true)"; if [[ "$a" == "200" || "$a" == "403" || "$b" == "200" || "$b" == "401" || "$b" == "403" ]]; then maybe "MetaAI" "yes/unknown ($(cc))"; else no "MetaAI" "no"; fi; }
kocowa(){ simple_200 "KOCOWA" "https://www.kocowa.com/"; }
tvbanywhere(){ simple_200 "TVBAnywhere+" "https://www.tvbanywhere.com/"; }

echo -e "${C_BLUE}Streaming unlock test${C_RESET}"
echo "IP mode   : ${IP_MODE}"
echo "IP country: $(cc)"
echo "----------------------------------------"
netflix
youtube
disney
prime
hbo
apple
spotify
tiktok
chatgpt
gemini
claude
bing_search
google_search
google_play
iqiyi
instagram_audio
metaai
one_trust
paramount
reddit
sonyliv
sora
steam_store
tvbanywhere
viu
abema
dazn
bilibili
kocowa
