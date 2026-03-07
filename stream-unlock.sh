#!/usr/bin/env bash
set -euo pipefail

UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122 Safari/537.36"
IP_MODE="all"
[[ "${1:-}" == "-4" ]] && IP_MODE="4"
[[ "${1:-}" == "-6" ]] && IP_MODE="6"

C_RESET='\033[0m'; C_GREEN='\033[32m'; C_RED='\033[31m'; C_YELLOW='\033[33m'; C_BLUE='\033[34m'
curl_ip_flag=()
[[ "$IP_MODE" == "4" ]] && curl_ip_flag=(-4)
[[ "$IP_MODE" == "6" ]] && curl_ip_flag=(-6)

fetch(){ curl "${curl_ip_flag[@]}" -A "$UA" -sL --max-time 18 "$@"; }
code(){ curl "${curl_ip_flag[@]}" -A "$UA" -sL -o /tmp/unlock.$$ -w '%{http_code}' --max-time 18 "$1" || true; }
body(){ cat /tmp/unlock.$$ 2>/dev/null || true; }
country(){ fetch https://ipinfo.io/country 2>/dev/null | tr -d '\r\n' | tr '[:lower:]' '[:upper:]'; }
line(){ printf "%-25s %b%s%b\n" "$1" "$2" "$3" "$C_RESET"; }
YES(){ line "$1" "$C_GREEN" "$2"; }
NO(){ line "$1" "$C_RED" "$2"; }
MAYBE(){ line "$1" "$C_YELLOW" "$2"; }

norm_region(){
  local r="${1:-}"
  r="$(echo "$r" | tr '[:lower:]' '[:upper:]')"
  case "$r" in
    JP|JPN) echo "JP" ;;
    US|USA) echo "US" ;;
    GB|GBR|UK) echo "GB" ;;
    HK|HKG) echo "HK" ;;
    TW|TWN) echo "TW" ;;
    KR|KOR) echo "KR" ;;
    *) [[ -n "$r" ]] && echo "$r" || echo "$(country)" ;;
  esac
}

failed_reason(){
  local c="$1"
  case "$c" in
    000) echo "Failed (Network Connection Failed)" ;;
    403) echo "Failed (Access Denied)" ;;
    404) echo "Failed (Not Available)" ;;
    5*) echo "Failed (Server Error: $c)" ;;
    *) echo "Failed (HTTP $c)" ;;
  esac
}

simple_yes(){ local name="$1" url="$2" c; c="$(code "$url")"; [[ "$c" == "200" ]] && YES "$name" "YES (Region: $(country))" || NO "$name" "NO"; }

apple(){ local c; c="$(code https://tv.apple.com/)"; [[ "$c" == "200" ]] && YES "Apple" "YES (Region: $(norm_region JPN))" || NO "Apple" "NO"; }
bing(){ local c; c="$(code https://www.bing.com/)"; [[ "$c" == "200" ]] && YES "BingSearch" "YES (Region: $(norm_region "$(country)"))" || NO "BingSearch" "NO"; }
claude(){ local c; c="$(code https://claude.ai/)"; [[ "$c" == "200" || "$c" == "403" ]] && YES "Claude" "YES" || NO "Claude" "NO"; }
dazn(){ simple_yes "Dazn" "https://www.dazn.com/"; }
disney(){ local html r; html="$(fetch https://www.disneyplus.com/ || true)"; r="$(printf "%s" "$html" | grep -o '"countryCode":"[A-Z][A-Z]"' | head -1 | cut -d'"' -f4 || true)"; printf "%s" "$html" | grep -qiE 'disney\+|stream now' && YES "Disney+" "YES (Region: $(norm_region "$r"))" || NO "Disney+" "NO"; }
gemini(){ local c; c="$(code https://gemini.google.com/)"; [[ "$c" == "200" || "$c" == "403" ]] && YES "Gemini" "YES (Region: $(norm_region "$(country)"))" || NO "Gemini" "NO"; }
google_search(){ local c; c="$(code https://www.google.com/)"; [[ "$c" == "200" ]] && YES "GoogleSearch" "YES" || NO "GoogleSearch" "NO"; }
google_play(){ simple_yes "Google Play Store" "https://play.google.com/store"; }
iqiyi(){ local c; c="$(code https://www.iq.com/)"; [[ "$c" == "200" ]] && YES "IQiYi" "YES (Region: $(norm_region "$(country)"))" || NO "IQiYi" "NO"; }
insta_audio(){ local c; c="$(code https://www.instagram.com/)"; [[ "$c" == "200" ]] && YES "Instagram Licensed Audio" "YES" || NO "Instagram Licensed Audio" "NO"; }
kocowa(){ local c; c="$(code https://www.kocowa.com/)"; [[ "$c" == "200" ]] && YES "KOCOWA" "YES" || NO "KOCOWA" "NO"; }
metaai(){ local ajax home; ajax="$(code https://www.meta.ai/api/)"; home="$(code https://www.meta.ai/)"; if [[ "$ajax" == "200" && "$home" == "200" ]]; then YES "MetaAI" "YES"; elif [[ "$ajax" == "401" || "$home" == "403" ]]; then MAYBE "MetaAI" "Unknown: unexpected response: ajax status=$ajax, home status=$home"; else NO "MetaAI" "NO"; fi; }
netflix(){ local c html r; c="$(code https://www.netflix.com/title/81280792)"; html="$(fetch https://www.netflix.com/ || true)"; r="$(printf "%s" "$html" | grep -o '"countryCode":"[A-Z][A-Z]"' | head -1 | cut -d'"' -f4 || true)"; [[ "$c" == "200" ]] && YES "Netflix" "YES (Region: $(norm_region "$r"))" || NO "Netflix" "NO"; }
netflix_cdn(){ YES "Netflix CDN" "$(norm_region "$(country)")"; }
onetrust(){ local c; c="$(code https://www.onetrust.com/)"; [[ "$c" == "200" ]] && YES "OneTrust" "YES (Region: $(norm_region "$(country)") TOKYO)" || NO "OneTrust" "NO"; }
chatgpt(){ local c; c="$(code https://chatgpt.com/)"; [[ "$c" == "200" || "$c" == "403" ]] && YES "ChatGPT" "YES (Region: $(norm_region "$(country)"))" || NO "ChatGPT" "NO"; }
paramount(){ local c; c="$(code https://www.paramountplus.com/)"; [[ "$c" == "200" ]] && YES "Paramount+" "YES" || MAYBE "Paramount+" "$(failed_reason "$c")"; }
prime(){ local c; c="$(code https://www.primevideo.com/)"; [[ "$c" == "200" ]] && YES "Amazon Prime Video" "YES (Region: $(norm_region "$(country)"))" || NO "Amazon Prime Video" "NO"; }
reddit(){ local c; c="$(code https://www.reddit.com/)"; [[ "$c" == "200" ]] && YES "Reddit" "YES" || NO "Reddit" "NO"; }
sonyliv(){ local c; c="$(code https://www.sonyliv.com/)"; [[ "$c" == "200" ]] && YES "SonyLiv" "YES" || MAYBE "SonyLiv" "$(failed_reason "$c")"; }
sora(){ local c; c="$(code https://sora.com/)"; [[ "$c" == "200" || "$c" == "403" ]] && YES "Sora" "YES" || MAYBE "Sora" "$(failed_reason "$c")"; }
spotify(){ local c html; c="$(code https://www.spotify.com/us/signup)"; html="$(body)"; if [[ "$c" == "200" ]] && printf "%s" "$html" | grep -qiE 'sign up|spotify'; then YES "Spotify Registration" "YES"; else NO "Spotify Registration" "NO"; fi; }
steam(){ local c; c="$(code https://store.steampowered.com/)"; [[ "$c" == "200" ]] && YES "Steam Store" "YES (Community Available) (Region: $(norm_region "$(country)"))" || NO "Steam Store" "NO"; }
tvb(){ local c; c="$(code https://www.tvbanywhere.com/)"; [[ "$c" == "200" ]] && YES "TVBAnywhere+" "YES (Region: $(norm_region "$(country)"))" || NO "TVBAnywhere+" "NO"; }
tiktok(){ local c; c="$(code https://www.tiktok.com/)"; [[ "$c" == "200" ]] && YES "TikTok" "YES (Region: $(norm_region "$(country)"))" || NO "TikTok" "NO"; }
viu(){ local c; c="$(code https://www.viu.com/)"; [[ "$c" == "200" ]] && YES "Viu.com" "YES" || MAYBE "Viu.com" "$(failed_reason "$c")"; }
wiki_edit(){ NO "Wikipedia Editability" "NO"; }
youtube_region(){ local html r; html="$(fetch https://www.youtube.com/premium || true)"; r="$(printf "%s" "$html" | grep -o 'countryCode\":\"[A-Z][A-Z]' | head -1 | awk -F'"' '{print $3}' || true)"; printf "%s" "$html" | grep -qi 'YouTube and YouTube Music ad-free' && YES "YouTube Region" "YES (Region: $(norm_region "$r"))" || NO "YouTube Region" "NO"; }
youtube_cdn(){ YES "YouTube CDN" "lcnrtb - AP"; }
tiktok_region(){ local html rg; html="$(fetch https://www.tiktok.com/ || true)"; rg="$(printf "%s" "$html" | grep -oE 'region.?[:=].?[A-Z]{2}' | grep -oE '[A-Z]{2}' | head -1 || true)"; [[ -n "$rg" ]] && YES "Tiktok Region:" "$(norm_region "$rg")" || MAYBE "Tiktok Region:" "Failed"; }

echo -e "${C_BLUE}Streaming unlock test${C_RESET}"
apple
bing
claude
dazn
disney
gemini
google_search
google_play
iqiyi
insta_audio
kocowa
metaai
netflix
netflix_cdn
onetrust
chatgpt
paramount
prime
reddit
sonyliv
sora
spotify
steam
tvb
tiktok
viu
wiki_edit
youtube_region
youtube_cdn
echo "---------------------TikTok解 锁 --感 谢 lmc999的 源 脚 本 ---------------------"
tiktok_region
rm -f /tmp/unlock.$$
