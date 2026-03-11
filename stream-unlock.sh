#!/usr/bin/env bash
set -euo pipefail

UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122 Safari/537.36"
TIMEOUT=20
IP_MODE="all"
NO_GEO=0
JSON_MODE=0
ONLY_RAW=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -4) IP_MODE="4" ;;
    -6) IP_MODE="6" ;;
    --timeout)
      if [[ $# -lt 2 || "$2" == -* ]]; then
        echo "--timeout requires a numeric value" >&2
        exit 1
      fi
      shift; TIMEOUT="$1"
      ;;
    --no-geo) NO_GEO=1 ;;
    --json) JSON_MODE=1 ;;
    --only)
      if [[ $# -lt 2 || "$2" == -* ]]; then
        echo "--only requires a comma-separated value" >&2
        exit 1
      fi
      shift; ONLY_RAW="$1"
      ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
  shift
done

if ! [[ "$TIMEOUT" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "Invalid --timeout value: $TIMEOUT" >&2
  exit 1
fi

if [[ -t 1 && "$JSON_MODE" -eq 0 ]]; then
  C_RESET=$'\033[0m'; C_GREEN=$'\033[32m'; C_RED=$'\033[31m'; C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'
else
  C_RESET=''; C_GREEN=''; C_RED=''; C_YELLOW=''; C_BLUE=''
fi

curl_ip_flag=()
[[ "$IP_MODE" == "4" ]] && curl_ip_flag=(-4)
[[ "$IP_MODE" == "6" ]] && curl_ip_flag=(-6)
CURL_COMMON=("${curl_ip_flag[@]}" -A "$UA" -sL --compressed --max-time "$TIMEOUT")

check_deps(){
  local miss=()
  for c in curl grep sed tr head mktemp; do
    command -v "$c" >/dev/null 2>&1 || miss+=("$c")
  done
  if [[ ${#miss[@]} -gt 0 ]]; then
    echo "Missing dependencies: ${miss[*]}" >&2
    exit 1
  fi
}

fetch(){ curl "${CURL_COMMON[@]}" "$@" || true; }

http_code(){
  local url="$1" code
  code="$(curl "${CURL_COMMON[@]}" -o /dev/null -w '%{http_code}' "$url" 2>/dev/null || true)"
  [[ -n "$code" ]] || code="000"
  printf '%s\n' "$code"
}

http_get(){
  # usage: http_get <url> <out_code_var> <out_body_var>
  local url="$1" out_code="$2" out_body="$3" tmp code body
  tmp="$(mktemp -t unlock-http.XXXXXX)"
  code="$(curl "${CURL_COMMON[@]}" -o "$tmp" -w '%{http_code}' "$url" 2>/dev/null || true)"
  [[ -n "$code" ]] || code="000"
  body="$(<"$tmp" 2>/dev/null || true)"
  rm -f "$tmp"
  printf -v "$out_code" '%s' "$code"
  printf -v "$out_body" '%s' "$body"
}

# ---------- geo ----------
GEO_IP=""; GEO_CC=""; GEO_COUNTRY=""; GEO_REGION=""; GEO_CITY=""

# Best-effort JSON extraction for simple flat JSON fields (no jq dependency).
# 不是完整 JSON parser；遇到复杂嵌套/转义字段可能不准确。
parse_json_field(){
  local key="$1"
  sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1
}

load_geo(){
  [[ "$NO_GEO" -eq 1 ]] && return 0
  local j
  j="$(fetch https://ipapi.co/json/)"
  if [[ -n "$j" ]] && grep -q '"country"' <<<"$j"; then
    GEO_IP="$(printf '%s' "$j" | parse_json_field ip)"
    GEO_CC="$(printf '%s' "$j" | parse_json_field country)"
    GEO_COUNTRY="$(printf '%s' "$j" | parse_json_field country_name)"
    GEO_REGION="$(printf '%s' "$j" | parse_json_field region)"
    GEO_CITY="$(printf '%s' "$j" | parse_json_field city)"
  fi
  if [[ -z "$GEO_CC" ]]; then
    j="$(fetch https://ipwho.is/)"
    GEO_IP="$(printf '%s' "$j" | parse_json_field ip)"
    GEO_CC="$(printf '%s' "$j" | parse_json_field country_code)"
    GEO_COUNTRY="$(printf '%s' "$j" | parse_json_field country)"
    GEO_REGION="$(printf '%s' "$j" | parse_json_field region)"
    GEO_CITY="$(printf '%s' "$j" | parse_json_field city)"
  fi
  if [[ -z "$GEO_CC" ]]; then
    GEO_CC="$(fetch https://ipinfo.io/country | tr -d '\r\n')"
  fi
}

norm_region(){
  local r="${1:-}"
  r="$(printf '%s' "$r" | tr '[:lower:]' '[:upper:]')"
  case "$r" in
    JP|JPN) printf '%s\n' JP ;;
    US|USA) printf '%s\n' US ;;
    GB|GBR|UK) printf '%s\n' GB ;;
    HK|HKG) printf '%s\n' HK ;;
    TW|TWN) printf '%s\n' TW ;;
    KR|KOR) printf '%s\n' KR ;;
    CN|CHN) printf '%s\n' CN ;;
    SG|SGP) printf '%s\n' SG ;;
    DE|DEU) printf '%s\n' DE ;;
    FR|FRA) printf '%s\n' FR ;;
    IN|IND) printf '%s\n' IN ;;
    *) printf '%s\n' "$r" ;;
  esac
}

extract_region_regex(){
  local text="$1" regex="$2" r
  r="$(printf '%s' "$text" | grep -oE "$regex" | head -1 | grep -oE '[A-Z]{2}' || true)"
  norm_region "$r"
}
extract_quoted_country(){
  extract_region_regex "$1" 'countryCode"[: ]+"[A-Z]{2}"'
}

extract_region_any(){
  local html="$1" r=""
  # strict / higher-confidence hints only
  r="$(extract_region_regex "$html" 'INNERTUBE_CONTEXT_GL"[: ]+"[A-Z]{2}"')"
  [[ -n "$r" ]] || r="$(extract_region_regex "$html" 'currentTerritory["=: ]+[A-Z]{2}')"
  [[ -n "$r" ]] || r="$(extract_region_regex "$html" '"countryCode":"[A-Z]{2}"')"
  printf '%s\n' "$r"
}

service_region_strict(){
  local html="$1"
  extract_region_any "$html"
}

classify_http(){
  local code="${1:-000}"
  case "$code" in
    200) printf '%s\n' YES ;;
    404) printf '%s\n' NO ;;
    403|429) printf '%s\n' BLOCKED_OR_CHALLENGED ;;
    *) printf '%s\n' UNKNOWN ;;
  esac
}

# ---------- output ----------
RESULTS_JSON=()

json_escape(){
  local s="$1"
  s=${s//\\/\\\\}; s=${s//"/\\"}; s=${s//$'\n'/\\n}; s=${s//$'\r'/}
  printf '%s' "$s"
}

emit_result(){
  local name="$1" status="$2" note="${3:-}" region="${4:-}"
  if [[ "$JSON_MODE" -eq 1 ]]; then
    local j
    j="{\"service\":\"$(json_escape "$name")\",\"status\":\"$(json_escape "$status")\""
    [[ -n "$note" ]] && j+=",\"note\":\"$(json_escape "$note")\""
    [[ -n "$region" ]] && j+=",\"region\":\"$(json_escape "$region")\""
    j+="}"
    RESULTS_JSON+=("$j")
    return
  fi

  local msg="$status"
  [[ -n "$note" ]] && msg+=" - $note"
  [[ -n "$region" ]] && msg+=" (Region: $region)"

  case "$status" in
    YES) printf "%-25s %b%s%b\n" "$name" "$C_GREEN" "$msg" "$C_RESET" ;;
    NO) printf "%-25s %b%s%b\n" "$name" "$C_RED" "$msg" "$C_RESET" ;;
    *) printf "%-25s %b%s%b\n" "$name" "$C_YELLOW" "$msg" "$C_RESET" ;;
  esac
}

emit_from_http(){
  local name="$1" code="$2" region="${3:-}"
  local cls
  cls="$(classify_http "$code")"
  emit_result "$name" "$cls" "" "$region"
}

# ---------- selection ----------
normalize_key(){ printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_+-'; }
canonical_key(){
  local k
  k="$(normalize_key "$1")"
  case "$k" in
    disneyplus) k="disney" ;;
    ytpremium|youtubepremium) k="youtube" ;;
    prime-video|primevideo) k="prime" ;;
    appletv|appletvplus) k="apple" ;;
    meta-ai) k="metaai" ;;
    tvbanywhere) k="tvb" ;;
  esac
  printf '%s\n' "$k"
}

declare -A ONLY_SET
if [[ -n "$ONLY_RAW" ]]; then
  IFS=',' read -r -a _arr <<<"$ONLY_RAW"
  for s in "${_arr[@]}"; do ONLY_SET["$(canonical_key "$s")"]=1; done
fi

enabled(){
  local k="$(canonical_key "$1")"
  [[ -z "$ONLY_RAW" ]] && return 0
  [[ -n "${ONLY_SET[$k]:-}" ]]
}

# ---------- probes ----------
probe_netflix(){
  enabled netflix || return 0
  local c1 c2 html region
  c1="$(http_code https://www.netflix.com/title/80018499)"
  c2="$(http_code https://www.netflix.com/title/70143836)"
  html="$(fetch https://www.netflix.com/)"
  region="$(extract_quoted_country "$html")"

  if [[ "$c2" == "200" ]]; then emit_result "Netflix" "YES" "Full Library" "$region"; return; fi
  if [[ "$c1" == "200" ]]; then emit_result "Netflix" "YES" "Originals Only" "$region"; return; fi

  # precedence: 403/429 (blocked/challenged) > 404 (no) > unknown
  if [[ "$c1" == "403" || "$c2" == "403" || "$c1" == "429" || "$c2" == "429" ]]; then
    emit_from_http "Netflix" "403" "$region"
  elif [[ "$c1" == "404" || "$c2" == "404" ]]; then
    emit_from_http "Netflix" "404" "$region"
  else
    emit_from_http "Netflix" "000" "$region"
  fi
}

probe_disney(){
  enabled disney || return 0
  local c html
  http_get "https://www.disneyplus.com/" c html

  if printf '%s' "$html" | grep -qiE 'disney\+|disneyplus|watch now on disney\+'; then
    emit_result "Disney+" "YES"; return
  fi
  if printf '%s' "$html" | grep -qiE 'not available in your region|currently unavailable|service unavailable in your location'; then
    emit_result "Disney+" "NO"; return
  fi
  emit_from_http "Disney+" "$c"
}

probe_youtube(){
  enabled youtube || return 0
  local c html region
  http_get "https://www.youtube.com/premium" c html
  region="$(norm_region "$(printf '%s' "$html" | sed -nE 's/.*"countryCode":"([A-Z]{2})".*/\1/p; t done; s/.*INNERTUBE_CONTEXT_GL":"([A-Z]{2})".*/\1/p; :done' | head -1)")"

  if printf '%s' "$html" | grep -qiE 'Premium is not available in your country|not available in your country|此国家/地区不可用|所在国家.*不可用|在你的国家.*不可用'; then
    emit_result "YouTube Premium" "NO"; return
  fi
  if printf '%s' "$html" | grep -qiE 'Get YouTube Premium|Try it free|YouTube and YouTube Music ad-free|Manage membership|youtube.com/premium'; then
    emit_result "YouTube Premium" "YES" "" "$region"; return
  fi
  # ambiguous page: keep conservative to avoid false positive YES on generic 200
  if [[ "$c" == "404" ]]; then
    emit_result "YouTube Premium" "NO"
  elif [[ "$c" == "403" || "$c" == "429" ]]; then
    emit_result "YouTube Premium" "BLOCKED_OR_CHALLENGED" "" "$region"
  else
    emit_result "YouTube Premium" "UNKNOWN" "" "$region"
  fi
}

probe_prime(){
  enabled prime || enabled primevideo || return 0
  local c html region
  http_get "https://www.primevideo.com/" c html
  region="$(extract_region_regex "$html" 'currentTerritory["=: ]+[A-Z]{2}')"
  if [[ "$c" == "200" ]] && printf '%s' "$html" | grep -qiE 'prime video|watch anywhere|watch now'; then
    emit_result "Amazon Prime Video" "YES" "" "$region"
  else
    emit_from_http "Amazon Prime Video" "$c" "$region"
  fi
}

probe_tiktok(){
  enabled tiktok || return 0
  local c html
  http_get "https://www.tiktok.com/" c html
  if [[ "$c" == "200" ]] && printf '%s' "$html" | grep -qi 'tiktok'; then
    emit_result "TikTok" "YES"
  else
    emit_from_http "TikTok" "$c"
  fi
}

probe_spotify(){
  enabled spotify || return 0
  local c html
  http_get "https://www.spotify.com/us/signup" c html
  if [[ "$c" == "200" ]] && printf '%s' "$html" | grep -qiE 'sign up|spotify'; then
    emit_result "Spotify Registration" "YES"
  else
    emit_from_http "Spotify Registration" "$c"
  fi
}

probe_chatgpt(){
  enabled chatgpt || return 0
  local c html
  http_get "https://chatgpt.com/" c html
  emit_from_http "ChatGPT" "$c"
}
probe_gemini(){
  enabled gemini || return 0
  local c html region
  http_get "https://gemini.google.com/" c html
  region="$(service_region_strict "$html")"
  emit_from_http "Gemini" "$c" "$region"
}
probe_claude(){
  enabled claude || return 0
  local c html
  http_get "https://claude.ai/" c html
  emit_from_http "Claude" "$c"
}
probe_apple(){
  enabled apple || return 0
  local c html
  http_get "https://tv.apple.com/" c html
  emit_from_http "Apple" "$c"
}
probe_sora(){
  enabled sora || return 0
  local c html
  http_get "https://sora.com/" c html
  emit_from_http "Sora" "$c"
}
probe_metaai(){
  enabled metaai || return 0
  local c html
  http_get "https://www.meta.ai/" c html
  emit_from_http "MetaAI (homepage)" "$c"
}

probe_basic_service(){
  local key="$1" name="$2" url="$3"
  enabled "$key" || return 0
  local c html
  http_get "$url" c html
  emit_from_http "$name" "$c"
}

# ---------- main ----------
check_deps
load_geo

if [[ "$JSON_MODE" -eq 0 ]]; then
  echo -e "${C_BLUE}Streaming unlock test${C_RESET}"
  [[ -n "$GEO_IP" ]] && echo "IP: $GEO_IP"
  if [[ -n "$GEO_COUNTRY$GEO_REGION$GEO_CITY$GEO_CC" ]]; then
    echo "Location: ${GEO_COUNTRY:-unknown}${GEO_REGION:+, $GEO_REGION}${GEO_CITY:+, $GEO_CITY}${GEO_CC:+ ($GEO_CC)}"
  fi
  echo "----------------------------------------"
fi

probe_netflix
probe_disney
probe_youtube
probe_prime
probe_tiktok
probe_spotify
probe_chatgpt
probe_gemini
probe_claude
probe_apple
probe_basic_service bing "BingSearch" "https://www.bing.com/"
probe_basic_service google "GoogleSearch" "https://www.google.com/"
probe_basic_service googleplay "Google Play Store" "https://play.google.com/store"
probe_basic_service iqiyi "IQiYi" "https://www.iq.com/"
probe_basic_service instagram "Instagram Licensed Audio" "https://www.instagram.com/"
probe_basic_service kocowa "KOCOWA" "https://www.kocowa.com/"
probe_metaai
probe_basic_service onetrust "OneTrust" "https://www.onetrust.com/"
probe_basic_service paramount "Paramount+" "https://www.paramountplus.com/"
probe_basic_service reddit "Reddit" "https://www.reddit.com/"
probe_basic_service sonyliv "SonyLiv" "https://www.sonyliv.com/"
probe_sora
probe_basic_service steam "Steam Store" "https://store.steampowered.com/"
probe_basic_service tvb "TVBAnywhere+" "https://www.tvbanywhere.com/"
probe_basic_service viu "Viu.com" "https://www.viu.com/"

if [[ "$JSON_MODE" -eq 1 ]]; then
  printf '{"ip":"%s","country":"%s","country_code":"%s","region":"%s","city":"%s","results":[' "$(json_escape "$GEO_IP")" "$(json_escape "$GEO_COUNTRY")" "$(json_escape "$GEO_CC")" "$(json_escape "$GEO_REGION")" "$(json_escape "$GEO_CITY")"
  for i in "${!RESULTS_JSON[@]}"; do
    [[ "$i" -gt 0 ]] && printf ','
    printf '%s' "${RESULTS_JSON[$i]}"
  done
  printf ']}\n'
fi
