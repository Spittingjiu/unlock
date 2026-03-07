#!/usr/bin/env bash
set -euo pipefail

UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122 Safari/537.36"
IP_MODE="all"
if [[ "${1:-}" == "-4" ]]; then IP_MODE="4"; fi
if [[ "${1:-}" == "-6" ]]; then IP_MODE="6"; fi

C_RESET='\033[0m'
C_GREEN='\033[32m'
C_RED='\033[31m'
C_YELLOW='\033[33m'
C_BLUE='\033[34m'

curl_ip_flag=()
[[ "$IP_MODE" == "4" ]] && curl_ip_flag=(-4)
[[ "$IP_MODE" == "6" ]] && curl_ip_flag=(-6)

say() {
  printf "%-14s %b%s%b\n" "$1" "$2" "$3" "$C_RESET"
}

fetch() {
  curl "${curl_ip_flag[@]}" -A "$UA" -sL --max-time 12 "$@"
}

head_code() {
  curl "${curl_ip_flag[@]}" -A "$UA" -sL -o /dev/null -w '%{http_code}' --max-time 15 "$1" || true
}

country_fallback() {
  fetch https://ipinfo.io/country 2>/dev/null | tr -d '\r\n'
}

ok() { say "$1" "$C_GREEN" "$2"; }
no() { say "$1" "$C_RED" "$2"; }
maybe() { say "$1" "$C_YELLOW" "$2"; }

filename_country() {
  country_fallback | tr '[:upper:]' '[:lower:]'
}

test_netflix() {
  local code cc html
  code="$(head_code https://www.netflix.com/title/81280792)"
  html="$(fetch https://www.netflix.com/ 2>/dev/null || true)"
  cc="$(printf "%s" "$html" | grep -o '"countryCode":"[A-Z][A-Z]"' | head -1 | cut -d'"' -f4 || true)"
  if [[ "$code" == "200" ]]; then ok "Netflix" "yes (${cc:-$(filename_country)})"; elif [[ "$code" == "403" || "$code" == "404" ]]; then no "Netflix" "no"; else maybe "Netflix" "maybe (${cc:-unknown})"; fi
}

test_youtube_premium() {
  local html cc
  html="$(fetch https://www.youtube.com/premium 2>/dev/null || true)"
  cc="$(printf "%s" "$html" | grep -o 'countryCode\":\"[A-Z][A-Z]' | head -1 | awk -F'"' '{print $3}' || true)"
  if printf "%s" "$html" | grep -qi "YouTube and YouTube Music ad-free"; then ok "YouTube" "yes (${cc:-$(filename_country)})"; else no "YouTube" "no"; fi
}

test_disney() {
  local html cc
  html="$(fetch https://www.disneyplus.com/ 2>/dev/null || true)"
  cc="$(printf "%s" "$html" | grep -o '"countryCode":"[A-Z][A-Z]"' | head -1 | cut -d'"' -f4 || true)"
  if printf "%s" "$html" | grep -qiE "disney\+|stream now"; then ok "Disney+" "yes (${cc:-$(filename_country)})"; else no "Disney+" "no"; fi
}

test_primevideo() {
  local html
  html="$(fetch https://www.primevideo.com/ 2>/dev/null || true)"
  if printf "%s" "$html" | grep -qiE "prime video|watch anywhere"; then ok "PrimeVideo" "yes ($(filename_country))"; else no "PrimeVideo" "no"; fi
}

test_hbo() {
  local html
  html="$(fetch https://play.max.com/ 2>/dev/null || true)"
  if printf "%s" "$html" | grep -qiE "max|hbo"; then ok "Max/HBO" "yes ($(filename_country))"; else no "Max/HBO" "no"; fi
}

test_apple_tv() {
  local code
  code="$(head_code https://tv.apple.com/)"
  if [[ "$code" == "200" ]]; then ok "AppleTV+" "yes ($(filename_country))"; else no "AppleTV+" "no"; fi
}

test_spotify() {
  local code
  code="$(head_code https://open.spotify.com/)"
  if [[ "$code" == "200" ]]; then ok "Spotify" "yes ($(filename_country))"; else no "Spotify" "no"; fi
}

test_tiktok() {
  local code
  code="$(head_code https://www.tiktok.com/)"
  if [[ "$code" == "200" ]]; then ok "TikTok" "yes ($(filename_country))"; else no "TikTok" "no"; fi
}

test_chatgpt() {
  local code
  code="$(head_code https://chatgpt.com/)"
  if [[ "$code" == "200" || "$code" == "403" ]]; then ok "ChatGPT" "yes ($(filename_country))"; else no "ChatGPT" "no"; fi
}

test_gemini() {
  local code
  code="$(head_code https://gemini.google.com/)"
  if [[ "$code" == "200" || "$code" == "403" ]]; then ok "Gemini" "yes ($(filename_country))"; else no "Gemini" "no"; fi
}

test_bilibili() {
  local code
  code="$(head_code https://api.bilibili.com/x/web-interface/nav)"
  if [[ "$code" == "200" ]]; then ok "Bilibili" "yes (cn/global)"; else no "Bilibili" "no"; fi
}

test_abema() {
  local code
  code="$(head_code https://abema.tv/)"
  if [[ "$code" == "200" ]]; then ok "Abema" "yes ($(filename_country))"; else no "Abema" "no"; fi
}

test_dazn() {
  local code
  code="$(head_code https://www.dazn.com/)"
  if [[ "$code" == "200" ]]; then ok "DAZN" "yes ($(filename_country))"; else no "DAZN" "no"; fi
}

main() {
  echo -e "${C_BLUE}Streaming unlock test${C_RESET}"
  echo "IP mode   : ${IP_MODE}"
  echo "IP country: $(filename_country)"
  echo "------------------------------"
  test_netflix
  test_youtube_premium
  test_disney
  test_primevideo
  test_hbo
  test_apple_tv
  test_spotify
  test_tiktok
  test_chatgpt
  test_gemini
  test_abema
  test_dazn
  test_bilibili
}

main
