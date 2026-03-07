#!/usr/bin/env bash
set -euo pipefail

UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122 Safari/537.36"

say() {
  printf "%-12s %s\n" "$1" "$2"
}

fetch() {
  curl -A "$UA" -sL --max-time 12 "$@"
}

country_fallback() {
  fetch https://ipinfo.io/country 2>/dev/null | tr -d '\r\n'
}

test_netflix() {
  local out code cc
  out="$(curl -A "$UA" -sL -o /tmp/nf.html -w '%{http_code}' --max-time 15 https://www.netflix.com/title/81280792 || true)"
  cc="$(fetch https://www.netflix.com/ 2>/dev/null | grep -o '"countryCode":"[A-Z][A-Z]"' | head -1 | cut -d'"' -f4 || true)"
  code="$out"
  if [[ "$code" == "200" ]]; then
    say "Netflix" "yes (${cc:-$(country_fallback | tr '[:upper:]' '[:lower:]')})"
  elif [[ "$code" == "403" || "$code" == "404" ]]; then
    say "Netflix" "no"
  else
    say "Netflix" "maybe (${cc:-unknown})"
  fi
}

test_youtube_premium() {
  local html cc
  html="$(fetch https://www.youtube.com/premium 2>/dev/null || true)"
  cc="$(printf "%s" "$html" | grep -o 'countryCode\":\"[A-Z][A-Z]' | head -1 | awk -F'"' '{print $3}' || true)"
  if printf "%s" "$html" | grep -qi "YouTube and YouTube Music ad-free"; then
    say "YouTube" "yes (${cc:-$(country_fallback | tr '[:upper:]' '[:lower:]')})"
  else
    say "YouTube" "no"
  fi
}

test_disney() {
  local html cc
  html="$(fetch https://www.disneyplus.com/ 2>/dev/null || true)"
  cc="$(printf "%s" "$html" | grep -o '"countryCode":"[A-Z][A-Z]"' | head -1 | cut -d'"' -f4 || true)"
  if printf "%s" "$html" | grep -qiE "disney\+|stream now"; then
    say "Disney+" "yes (${cc:-$(country_fallback | tr '[:upper:]' '[:lower:]')})"
  else
    say "Disney+" "no"
  fi
}

test_primevideo() {
  local html
  html="$(fetch https://www.primevideo.com/ 2>/dev/null || true)"
  if printf "%s" "$html" | grep -qiE "prime video|watch anywhere"; then
    say "PrimeVideo" "yes ($(country_fallback | tr '[:upper:]' '[:lower:]'))"
  else
    say "PrimeVideo" "no"
  fi
}

test_hbo() {
  local html
  html="$(fetch https://play.max.com/ 2>/dev/null || true)"
  if printf "%s" "$html" | grep -qiE "max|hbo"; then
    say "Max/HBO" "yes ($(country_fallback | tr '[:upper:]' '[:lower:]'))"
  else
    say "Max/HBO" "no"
  fi
}

test_bilibili() {
  local code
  code="$(curl -A "$UA" -sL -o /dev/null -w '%{http_code}' --max-time 12 https://api.bilibili.com/x/web-interface/nav || true)"
  if [[ "$code" == "200" ]]; then
    say "Bilibili" "yes (cn/global)"
  else
    say "Bilibili" "no"
  fi
}

main() {
  echo "Streaming unlock test"
  echo "IP country: $(country_fallback | tr '[:upper:]' '[:lower:]')"
  echo "------------------------------"
  test_netflix
  test_youtube_premium
  test_disney
  test_primevideo
  test_hbo
  test_bilibili
}

main
