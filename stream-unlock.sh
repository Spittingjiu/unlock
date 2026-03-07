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

echo -e "${C_BLUE}Streaming unlock test (core platforms)${C_RESET}"
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
rm -f /tmp/unlock.$$
