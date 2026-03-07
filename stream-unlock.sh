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
line(){ printf "%-25s %b%s%b\n" "$1" "$2" "$3" "$C_RESET"; }
YES(){ line "$1" "$C_GREEN" "$2"; }
NO(){ line "$1" "$C_RED" "$2"; }
UNKNOWN(){ line "$1" "$C_YELLOW" "$2"; }

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
    CN|CHN) echo "CN" ;;
    SG|SGP) echo "SG" ;;
    DE|DEU) echo "DE" ;;
    FR|FRA) echo "FR" ;;
    IN|IND) echo "IN" ;;
    *) [[ -n "$r" ]] && echo "$r" || echo "" ;;
  esac
}

yes_with_region(){
  local name="$1" region="$2"
  region="$(norm_region "$region")"
  if [[ -n "$region" ]]; then
    YES "$name" "YES (Region: $region)"
  else
    YES "$name" "YES"
  fi
}

extract_country_code(){
  local html="$1"
  printf "%s" "$html" | grep -oE 'countryCode["=: ]+[A-Z]{2}' | grep -oE '[A-Z]{2}' | head -1 || true
}

apple(){
  local c html r
  c="$(code https://tv.apple.com/)"
  html="$(body)"
  r="$(extract_country_code "$html")"
  if [[ "$c" == "200" ]]; then yes_with_region "Apple" "$r"; else NO "Apple" "NO"; fi
}

bing(){ local c; c="$(code https://www.bing.com/)"; [[ "$c" == "200" ]] && YES "BingSearch" "YES" || NO "BingSearch" "NO"; }
claude(){ local c; c="$(code https://claude.ai/)"; [[ "$c" == "200" || "$c" == "403" ]] && YES "Claude" "YES" || NO "Claude" "NO"; }
dazn(){ local c; c="$(code https://www.dazn.com/)"; [[ "$c" == "200" ]] && YES "Dazn" "YES" || NO "Dazn" "NO"; }

disney(){
  local html r
  html="$(fetch https://www.disneyplus.com/ || true)"
  r="$(printf "%s" "$html" | grep -o '"countryCode":"[A-Z][A-Z]"' | head -1 | cut -d'"' -f4 || true)"
  if printf "%s" "$html" | grep -qiE 'disney\+|stream now'; then yes_with_region "Disney+" "$r"; else NO "Disney+" "NO"; fi
}

gemini(){ local c; c="$(code https://gemini.google.com/)"; [[ "$c" == "200" || "$c" == "403" ]] && YES "Gemini" "YES" || NO "Gemini" "NO"; }
google_search(){ local c; c="$(code https://www.google.com/)"; [[ "$c" == "200" ]] && YES "GoogleSearch" "YES" || NO "GoogleSearch" "NO"; }
google_play(){ local c; c="$(code https://play.google.com/store)"; [[ "$c" == "200" ]] && YES "Google Play Store" "YES" || NO "Google Play Store" "NO"; }
iqiyi(){ local c; c="$(code https://www.iq.com/)"; [[ "$c" == "200" ]] && YES "IQiYi" "YES" || NO "IQiYi" "NO"; }
insta_audio(){ local c; c="$(code https://www.instagram.com/)"; [[ "$c" == "200" ]] && YES "Instagram Licensed Audio" "YES" || NO "Instagram Licensed Audio" "NO"; }
kocowa(){ local c; c="$(code https://www.kocowa.com/)"; [[ "$c" == "200" ]] && YES "KOCOWA" "YES" || NO "KOCOWA" "NO"; }
metaai(){ local ajax home; ajax="$(code https://www.meta.ai/api/)"; home="$(code https://www.meta.ai/)"; if [[ "$ajax" == "200" && "$home" == "200" ]]; then YES "MetaAI" "YES"; elif [[ "$ajax" == "401" || "$home" == "403" ]]; then UNKNOWN "MetaAI" "UNKNOWN"; else NO "MetaAI" "NO"; fi; }

netflix(){
  local c html r
  c="$(code https://www.netflix.com/title/81280792)"
  html="$(fetch https://www.netflix.com/ || true)"
  r="$(printf "%s" "$html" | grep -o '"countryCode":"[A-Z][A-Z]"' | head -1 | cut -d'"' -f4 || true)"
  [[ "$c" == "200" ]] && yes_with_region "Netflix" "$r" || NO "Netflix" "NO"
}

netflix_cdn(){ UNKNOWN "Netflix CDN" "UNKNOWN"; }
onetrust(){ local c; c="$(code https://www.onetrust.com/)"; [[ "$c" == "200" ]] && YES "OneTrust" "YES" || NO "OneTrust" "NO"; }
chatgpt(){ local c; c="$(code https://chatgpt.com/)"; [[ "$c" == "200" || "$c" == "403" ]] && YES "ChatGPT" "YES" || NO "ChatGPT" "NO"; }
paramount(){ local c; c="$(code https://www.paramountplus.com/)"; [[ "$c" == "200" ]] && YES "Paramount+" "YES" || NO "Paramount+" "NO"; }
prime(){ local c; c="$(code https://www.primevideo.com/)"; [[ "$c" == "200" ]] && YES "Amazon Prime Video" "YES" || NO "Amazon Prime Video" "NO"; }
reddit(){ local c; c="$(code https://www.reddit.com/)"; [[ "$c" == "200" ]] && YES "Reddit" "YES" || NO "Reddit" "NO"; }
sonyliv(){ local c; c="$(code https://www.sonyliv.com/)"; [[ "$c" == "200" ]] && YES "SonyLiv" "YES" || NO "SonyLiv" "NO"; }
sora(){ local c; c="$(code https://sora.com/)"; [[ "$c" == "200" || "$c" == "403" ]] && YES "Sora" "YES" || NO "Sora" "NO"; }
spotify(){ local c html; c="$(code https://www.spotify.com/us/signup)"; html="$(body)"; if [[ "$c" == "200" ]] && printf "%s" "$html" | grep -qiE 'sign up|spotify'; then YES "Spotify Registration" "YES"; else NO "Spotify Registration" "NO"; fi; }
steam(){ local c; c="$(code https://store.steampowered.com/)"; [[ "$c" == "200" ]] && YES "Steam Store" "YES" || NO "Steam Store" "NO"; }
tvb(){ local c; c="$(code https://www.tvbanywhere.com/)"; [[ "$c" == "200" ]] && YES "TVBAnywhere+" "YES" || NO "TVBAnywhere+" "NO"; }
tiktok(){ local c; c="$(code https://www.tiktok.com/)"; [[ "$c" == "200" ]] && YES "TikTok" "YES" || NO "TikTok" "NO"; }
viu(){ local c; c="$(code https://www.viu.com/)"; [[ "$c" == "200" ]] && YES "Viu.com" "YES" || NO "Viu.com" "NO"; }
wiki_edit(){ UNKNOWN "Wikipedia Editability" "UNKNOWN"; }

youtube_region(){
  local html r
  html="$(fetch https://www.youtube.com/premium || true)"
  r="$(printf "%s" "$html" | grep -o 'countryCode\":\"[A-Z][A-Z]' | head -1 | awk -F'"' '{print $3}' || true)"
  if printf "%s" "$html" | grep -qi 'YouTube and YouTube Music ad-free'; then yes_with_region "YouTube Region" "$r"; else NO "YouTube Region" "NO"; fi
}

youtube_cdn(){ UNKNOWN "YouTube CDN" "UNKNOWN"; }

tiktok_region(){
  local html rg
  html="$(fetch https://www.tiktok.com/ || true)"
  rg="$(printf "%s" "$html" | grep -oE 'region.?[:=].?[A-Z]{2}' | grep -oE '[A-Z]{2}' | head -1 || true)"
  [[ -n "$rg" ]] && YES "Tiktok Region:" "$(norm_region "$rg")" || UNKNOWN "Tiktok Region:" "UNKNOWN"
}

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
echo "--------------------- TikTok Region ---------------------"
tiktok_region
rm -f /tmp/unlock.$$
