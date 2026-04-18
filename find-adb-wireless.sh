#!/usr/bin/env bash
# Один проход: сканирует локальную сеть и ищет хосты с открытым TCP-портом (по умолчанию 5555, ADB wireless).
# Требуется nmap.
#
# Использование:
#   ./find-adb-wireless.sh [N]
#   ./find-adb-wireless.sh -port 6666 [N]
#   SUBNET=10.0.0.0/24 ./find-adb-wireless.sh 2
#
# Переменные окружения:
#   SUBNET — CIDR для скана (иначе авто: Linux — с интерфейса по умолчанию, macOS — *.0/24)

set -euo pipefail

# macOS: при запуске не из login-shell в PATH часто нет Homebrew
[[ -d /opt/homebrew/bin ]] && PATH="/opt/homebrew/bin:$PATH"
[[ -d /usr/local/bin ]] && PATH="/usr/local/bin:$PATH"
export PATH

SCAN_PORT=5555
TARGET_COUNT=1
positional=()

usage() {
  echo "usage: $(basename "$0") [-port P] [N]" >&2
  echo "  -port P — TCP-порт для проверки (по умолчанию 5555)" >&2
  echo "  N — сколько адресов вывести из найденных (по умолчанию 1)" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -port|--port)
      if [[ -z "${2:-}" ]] || ! [[ "$2" =~ ^[0-9]+$ ]] || (( 10#$2 < 1 || 10#$2 > 65535 )); then
        echo "error: после $1 укажите номер порта 1..65535" >&2
        usage
        exit 1
      fi
      SCAN_PORT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "error: неизвестная опция: $1" >&2
      usage
      exit 1
      ;;
    *)
      positional+=("$1")
      shift
      ;;
  esac
done

if (( ${#positional[@]} > 1 )); then
  echo "error: лишние аргументы: ${positional[*]}" >&2
  usage
  exit 1
fi

if (( ${#positional[@]} == 1 )); then
  TARGET_COUNT="${positional[0]}"
fi

if ! [[ "$TARGET_COUNT" =~ ^[1-9][0-9]*$ ]]; then
  echo "error: N должно быть целым числом ≥ 1" >&2
  usage
  exit 1
fi

if ! command -v nmap >/dev/null 2>&1; then
  echo "error: нужен nmap (brew install nmap)" >&2
  exit 2
fi

detect_network() {
  if [[ -n "${SUBNET:-}" ]]; then
    echo "$SUBNET"
    return 0
  fi

  if command -v ip >/dev/null 2>&1; then
    local iface cidr
    iface=$(ip -4 route show default 2>/dev/null | awk '{print $5; exit}')
    if [[ -n "$iface" ]]; then
      cidr=$(ip -4 -o addr show dev "$iface" 2>/dev/null | awk '{print $4; exit}')
      if [[ -n "$cidr" ]]; then
        echo "$cidr"
        return 0
      fi
    fi
  fi

  local iface ip
  iface=$(route -n get default 2>/dev/null | awk '/interface:/{print $2; exit}')
  if [[ -z "$iface" ]]; then
    echo "error: не удалось определить интерфейс по умолчанию; задайте SUBNET=" >&2
    return 1
  fi
  ip=$(ifconfig "$iface" 2>/dev/null | awk '/inet / && $2 !~ /^127\./ {print $2; exit}')
  if [[ -z "$ip" ]]; then
    echo "error: нет IPv4 на интерфейсе $iface; задайте SUBNET=" >&2
    return 1
  fi
  echo "${ip%.*}.0/24"
}

scan_once() {
  local net="$1"
  local port="$2"
  nmap -p "$port" --open -Pn -n --max-retries 1 --host-timeout 2s "$net" -oG - 2>/dev/null \
    | awk -v p="$port" '$0 ~ p "/open" { print $2 }' | sort -u
}

NET=$(detect_network) || exit 3
echo "Сканирование: $NET (порт $SCAN_PORT/open, вывести до $TARGET_COUNT адрес(ов))" >&2

found=()
while IFS= read -r ip; do
  [[ -n "$ip" ]] && found+=("$ip")
done < <(scan_once "$NET" "$SCAN_PORT")

if (( ${#found[@]} < TARGET_COUNT )); then
  echo "error: найдено ${#found[@]}, требуется минимум $TARGET_COUNT" >&2
  (( ${#found[@]} > 0 )) && printf '%s\n' "${found[@]}"
  exit 4
fi

printf '%s\n' "${found[@]:0:TARGET_COUNT}"
