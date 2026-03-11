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

fetch(){ curl "${curl_ip_flag[@]}" -A "$UA" -sL --compressed --max-time 20 "$@"; }
code(){ curl "${curl_ip_flag[@]}" -A "$UA" -sL --compressed -o /tmp/unlock.$$ -w '%{http_code}' --max-time 20 "$1" || true; }
body(){ cat /tmp/unlock.$$ 2>/dev/null || true; }
line(){ printf "%-25s %b%s%b\n" "$1" "$2" "$3" "$C_RESET"; }
YES(){ line "$1" "$C_GREEN" "$2"; }
NO(){ line "$1" "$C_RED" "$2"; }
UNKNOWN(){ line "$1" "$C_YELLOW" "$2"; }

GEO_IP=""
GEO_CC=""
GEO_COUNTRY=""
GEO_REGION=""
GEO_CITY=""

parse_json_field(){
  local key="$1"
  sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1
}

load_geo(){
  local j
  j="$(fetch https://ipapi.co/json/ || true)"
  if [[ -n "$j" ]] && grep -q '"country"' <<<"$j"; then
    GEO_IP="$(printf "%s" "$j" | parse_json_field ip)"
    GEO_CC="$(printf "%s" "$j" | parse_json_field country)"
    GEO_COUNTRY="$(printf "%s" "$j" | parse_json_field country_name)"
    GEO_REGION="$(printf "%s" "$j" | parse_json_field region)"
    GEO_CITY="$(printf "%s" "$j" | parse_json_field city)"
  fi
  if [[ -z "$GEO_CC" ]]; then
    j="$(fetch https://ipwho.is/ || true)"
    GEO_IP="$(printf "%s" "$j" | parse_json_field ip)"
    GEO_CC="$(printf "%s" "$j" | parse_json_field country_code)"
    GEO_COUNTRY="$(printf "%s" "$j" | parse_json_field country)"
    GEO_REGION="$(printf "%s" "$j" | parse_json_field region)"
    GEO_CITY="$(printf "%s" "$j" | parse_json_field city)"
  fi
  if [[ -z "$GEO_CC" ]]; then
    GEO_CC="$(fetch https://ipinfo.io/country | tr -d '\r\n' || true)"
  fi
}

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

extract_quoted_country(){
  local html="$1"
  printf "%s" "$html" | grep -oE 'countryCode"[: ]+"[A-Z]{2}"' | head -1 | grep -oE '[A-Z]{2}' || true
}

netflix(){
  local original full c1 c2 html region
  original="https://www.netflix.com/title/80018499"
  full="https://www.netflix.com/title/70143836"
  c1="$(code "$original")"
  c2="$(code "$full")"
  html="$(fetch https://www.netflix.com/ || true)"
  region="$(extract_quoted_country "$html")"
  region="$(norm_region "$region")"

  if [[ "$c2" == "200" ]]; then
    [[ -n "$region" ]] && YES "Netflix" "YES (Full Library / Region: $region)" || YES "Netflix" "YES (Full Library)"
  elif [[ "$c1" == "200" ]]; then
    YES "Netflix" "YES (Originals Only)"
  elif [[ "$c1" == "403" || "$c2" == "403" || "$c1" == "404" || "$c2" == "404" ]]; then
    NO "Netflix" "NO"
  else
    UNKNOWN "Netflix" "UNKNOWN"
  fi
}

disney(){
  local html region
  html="$(fetch https://www.disneyplus.com/ || true)"
  region="$(printf "%s" "$html" | grep -o '"countryCode":"[A-Z][A-Z]"' | head -1 | cut -d'"' -f4 || true)"
  region="$(norm_region "$region")"
  if printf "%s" "$html" | grep -qiE 'disney\+|stream now'; then
    [[ -n "$region" ]] && YES "Disney+" "YES (Region: $region)" || YES "Disney+" "YES"
  elif [[ -n "$html" ]]; then
    NO "Disney+" "NO"
  else
    UNKNOWN "Disney+" "UNKNOWN"
  fi
}

youtube(){
  local html region
  html="$(fetch https://www.youtube.com/premium || true)"
  region="$(printf "%s" "$html" | grep -o 'countryCode\":\"[A-Z][A-Z]' | head -1 | awk -F'"' '{print $3}' || true)"
  region="$(norm_region "$region")"
  if printf "%s" "$html" | grep -qi 'YouTube and YouTube Music ad-free'; then
    [[ -n "$region" ]] && YES "YouTube Region" "YES (Region: $region)" || YES "YouTube Region" "YES"
  elif [[ -n "$html" ]]; then
    NO "YouTube Region" "NO"
  else
    UNKNOWN "YouTube Region" "UNKNOWN"
  fi
}

prime(){
  local c html region
  c="$(code https://www.primevideo.com/)"
  html="$(body)"
  region="$(printf "%s" "$html" | grep -oE 'currentTerritory["=: ]+[A-Z]{2}' | grep -oE '[A-Z]{2}' | head -1 || true)"
  region="$(norm_region "$region")"
  if [[ "$c" == "200" ]]; then
    [[ -n "$region" ]] && YES "Amazon Prime Video" "YES (Region: $region)" || YES "Amazon Prime Video" "YES"
  elif [[ "$c" == "403" || "$c" == "404" ]]; then
    NO "Amazon Prime Video" "NO"
  else
    UNKNOWN "Amazon Prime Video" "UNKNOWN"
  fi
}

tiktok(){
  local c html region
  c="$(code https://www.tiktok.com/)"
  html="$(body)"
  region="$(printf "%s" "$html" | grep -oE '"region":"[A-Z]{2}"' | head -1 | cut -d'"' -f4 || true)"
  region="$(norm_region "$region")"
  if [[ "$c" == "200" ]]; then
    [[ -n "$region" ]] && YES "TikTok" "YES (Region: $region)" || YES "TikTok" "YES"
  elif [[ "$c" == "403" || "$c" == "404" ]]; then
    NO "TikTok" "NO"
  else
    UNKNOWN "TikTok" "UNKNOWN"
  fi
}

spotify(){
  local c html region
  c="$(code https://www.spotify.com/us/signup)"
  html="$(body)"
  region="$(printf "%s" "$html" | grep -oE 'country["=: ]+"[A-Z]{2}"' | head -1 | grep -oE '[A-Z]{2}' || true)"
  region="$(norm_region "$region")"
  if [[ "$c" == "200" ]] && printf "%s" "$html" | grep -qiE 'sign up|spotify'; then
    [[ -n "$region" ]] && YES "Spotify Registration" "YES (Region: $region)" || YES "Spotify Registration" "YES"
  elif [[ "$c" == "403" || "$c" == "404" ]]; then
    NO "Spotify Registration" "NO"
  else
    UNKNOWN "Spotify Registration" "UNKNOWN"
  fi
}

chatgpt(){
  local c
  c="$(code https://chatgpt.com/)"
  if [[ "$c" == "200" || "$c" == "403" ]]; then
    YES "ChatGPT" "YES"
  elif [[ "$c" == "404" ]]; then
    NO "ChatGPT" "NO"
  else
    UNKNOWN "ChatGPT" "UNKNOWN"
  fi
}

gemini(){
  local c html region
  c="$(code https://gemini.google.com/)"
  html="$(body)"
  region="$(printf "%s" "$html" | grep -oE 'countryCode["=: ]+"[A-Z]{2}"' | head -1 | grep -oE '[A-Z]{2}' || true)"
  region="$(norm_region "$region")"
  if [[ "$c" == "200" || "$c" == "403" ]]; then
    [[ -n "$region" ]] && YES "Gemini" "YES (Region: $region)" || YES "Gemini" "YES"
  elif [[ "$c" == "404" ]]; then
    NO "Gemini" "NO"
  else
    UNKNOWN "Gemini" "UNKNOWN"
  fi
}

claude(){
  local c
  c="$(code https://claude.ai/)"
  if [[ "$c" == "200" || "$c" == "403" ]]; then
    YES "Claude" "YES"
  elif [[ "$c" == "404" ]]; then
    NO "Claude" "NO"
  else
    UNKNOWN "Claude" "UNKNOWN"
  fi
}


extra_simple_yes(){
  local name="$1" url="$2" c
  c="$(code "$url")"
  if [[ "$c" == "200" ]]; then
    YES "$name" "YES"
  elif [[ "$c" == "403" || "$c" == "404" ]]; then
    NO "$name" "NO"
  else
    UNKNOWN "$name" "UNKNOWN"
  fi
}

bing_extra(){ extra_simple_yes "BingSearch" "https://www.bing.com/"; }
google_search_extra(){ extra_simple_yes "GoogleSearch" "https://www.google.com/"; }
google_play_extra(){ extra_simple_yes "Google Play Store" "https://play.google.com/store"; }
iqiyi_extra(){ extra_simple_yes "IQiYi" "https://www.iq.com/"; }
insta_audio_extra(){ extra_simple_yes "Instagram Licensed Audio" "https://www.instagram.com/"; }
kocowa_extra(){ extra_simple_yes "KOCOWA" "https://www.kocowa.com/"; }
onetrust_extra(){ extra_simple_yes "OneTrust" "https://www.onetrust.com/"; }
paramount_extra(){ extra_simple_yes "Paramount+" "https://www.paramountplus.com/"; }
reddit_extra(){ extra_simple_yes "Reddit" "https://www.reddit.com/"; }
sonyliv_extra(){ extra_simple_yes "SonyLiv" "https://www.sonyliv.com/"; }
sora_extra(){
  local c
  c="$(code https://sora.com/)"
  if [[ "$c" == "200" || "$c" == "403" ]]; then
    YES "Sora" "YES"
  elif [[ "$c" == "404" ]]; then
    NO "Sora" "NO"
  else
    UNKNOWN "Sora" "UNKNOWN"
  fi
}
steam_extra(){ extra_simple_yes "Steam Store" "https://store.steampowered.com/"; }
tvb_extra(){ extra_simple_yes "TVBAnywhere+" "https://www.tvbanywhere.com/"; }
viu_extra(){ extra_simple_yes "Viu.com" "https://www.viu.com/"; }
metaai_extra(){
  local ajax home
  ajax="$(code https://www.meta.ai/api/)"
  home="$(code https://www.meta.ai/)"
  if [[ "$ajax" == "200" && "$home" == "200" ]]; then
    YES "MetaAI" "YES"
  elif [[ "$ajax" == "401" || "$home" == "403" ]]; then
    UNKNOWN "MetaAI" "UNKNOWN"
  elif [[ "$ajax" == "403" || "$home" == "404" ]]; then
    NO "MetaAI" "NO"
  else
    UNKNOWN "MetaAI" "UNKNOWN"
  fi
}

apple(){
  local c html region
  c="$(code https://tv.apple.com/)"
  html="$(body)"
  region="$(extract_quoted_country "$html")"
  region="$(norm_region "$region")"
  if [[ "$c" == "200" ]]; then
    [[ -n "$region" ]] && YES "Apple" "YES (Region: $region)" || YES "Apple" "YES"
  elif [[ "$c" == "403" || "$c" == "404" ]]; then
    NO "Apple" "NO"
  else
    UNKNOWN "Apple" "UNKNOWN"
  fi
}

load_geo
echo -e "${C_BLUE}Streaming unlock test${C_RESET}"
[[ -n "$GEO_IP" ]] && echo "IP: $GEO_IP"
if [[ -n "$GEO_COUNTRY$GEO_REGION$GEO_CITY$GEO_CC" ]]; then
  echo "Location: ${GEO_COUNTRY:-unknown}${GEO_REGION:+, $GEO_REGION}${GEO_CITY:+, $GEO_CITY}${GEO_CC:+ ($GEO_CC)}"
fi
echo "----------------------------------------"
netflix
disney
youtube
prime
tiktok
spotify
chatgpt
gemini
claude
apple
bing_extra
google_search_extra
google_play_extra
iqiyi_extra
insta_audio_extra
kocowa_extra
metaai_extra
onetrust_extra
paramount_extra
reddit_extra
sonyliv_extra
sora_extra
steam_extra
tvb_extra
viu_extra
rm -f /tmp/unlock.$$
