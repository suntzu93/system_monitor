#!/bin/bash

# Load environment variables from the .env file
source $HOME/.env
API_URL="https://api.telegram.org/bot${BOT_TOKEN}/sendMessage"

# 85% threshold
CPU_THRESHOLD=85
MEMORY_THRESHOLD=85
NETWORK_THRESHOLD_MBPS=850  # 85% of 1 Gbps
DISK_THRESHOLD=85

# Function to escape text for MarkdownV2
escape_markdownv2() {
  local text="$1"
  text="$(echo "$text" | sed 's/\\/\\\\/g')"       # Escape backslash first
  text="$(echo "$text" | sed 's/\_/\\_/g')"        # Escape underscore
  text="$(echo "$text" | sed 's/\*/\\*/g')"        # Escape asterisk
  text="$(echo "$text" | sed 's/\[/\\[/g')"        # Escape open square bracket
  text="$(echo "$text" | sed 's/\]/\\]/g')"        # Escape close square bracket
  text="$(echo "$text" | sed 's/(/\\(/g')"         # Escape open parenthesis
  text="$(echo "$text" | sed 's/)/\\)/g')"         # Escape close parenthesis
  text="$(echo "$text" | sed 's/~/\\~/g')"         # Escape tilde
  text="$(echo "$text" | sed 's/`/\\`/g')"         # Escape backtick
  text="$(echo "$text" | sed 's/>/\\>/g')"         # Escape greater than
  text="$(echo "$text" | sed 's/#/\\#/g')"         # Escape hash
  text="$(echo "$text" | sed 's/\+/\\+/g')"        # Escape plus
  text="$(echo "$text" | sed 's/-/\\-/g')"         # Escape minus/hyphen
  text="$(echo "$text" | sed 's/=/\\=/g')"         # Escape equal sign
  text="$(echo "$text" | sed 's/|/\\|/g')"         # Escape pipe
  text="$(echo "$text" | sed 's/{/\\{/g')"         # Escape open curly brace
  text="$(echo "$text" | sed 's/}/\\}/g')"         # Escape close curly brace
  text="$(echo "$text" | sed 's/\./\\./g')"        # Escape dot
  text="$(echo "$text" | sed 's/!/\\!/g')"         # Escape exclamation mark
  echo "$text"
}

# Function to send a message to Telegram
send_telegram_message() {
  local message="$1"
  curl -s -X POST "$API_URL" \
    --data-urlencode "chat_id=$CHAT_ID" \
    --data-urlencode "parse_mode=MarkdownV2" \
    --data-urlencode "text=$message"
}

get_server_ip() {
  local ip
  ip=$(hostname -I | awk '{print $1}')
  echo "$ip"
}

# File to store metrics counts
METRIC_FILE="/tmp/system_monitor_metrics"
# Initialize metrics file if it doesn't exist
if [ ! -f "$METRIC_FILE" ]; then
  echo "0 0 0" > "$METRIC_FILE"
fi

echo "-------------------------------"
echo "Starting system monitor script."

# Get server IP address
SERVER_IP=$(get_server_ip)
echo "Server IP: $SERVER_IP"

read CPU_COUNT MEMORY_COUNT NETWORK_COUNT < "$METRIC_FILE"

echo "Checking CPU usage..."
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
echo "Current CPU Usage: $CPU_USAGE%"

if (( $(echo "$CPU_USAGE > $CPU_THRESHOLD" | bc -l) )); then
  echo "CPU usage is above threshold."
  CPU_COUNT=$((CPU_COUNT + 1))
else
  CPU_COUNT=0
fi

echo "Checking Memory usage..."
MEMORY_USAGE=$(free | grep Mem | awk '{print $3/$2 * 100.0}')
echo "Current Memory Usage: $MEMORY_USAGE%"

if (( $(echo "$MEMORY_USAGE > $MEMORY_THRESHOLD" | bc -l) )); then
  echo "Memory usage is above threshold."
  MEMORY_COUNT=$((MEMORY_COUNT + 1))
else
  MEMORY_COUNT=0
fi

echo "Checking network usage..."
# Detect available network interfaces
INTERFACES=( $(ls /sys/class/net) )
# shellcheck disable=SC2145
echo "Available network interfaces: ${INTERFACES[@]}"

# Choose the first non-loopback interface with traffic
for INTERFACE in "${INTERFACES[@]}"; do
  if [ "$INTERFACE" != "lo" ]; then
    RX_BYTES_BEFORE=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes 2>/dev/null)
    TX_BYTES_BEFORE=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes 2>/dev/null)
    sleep 1
    RX_BYTES_AFTER=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes 2>/dev/null)
    TX_BYTES_AFTER=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes 2>/dev/null)

    if [ "$RX_BYTES_BEFORE" != "$RX_BYTES_AFTER" ] || [ "$TX_BYTES_BEFORE" != "$TX_BYTES_AFTER" ]; then
      echo "Using active network interface: $INTERFACE"
      break
    fi
  fi
done

if [ -n "$INTERFACE" ]; then
  RX_BYTES_BEFORE=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes)
  TX_BYTES_BEFORE=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes)
  SLEEP_INTERVAL=1  # 1 second interval

  echo "RX Bytes before: $RX_BYTES_BEFORE"
  echo "TX Bytes before: $TX_BYTES_BEFORE"

  sleep $SLEEP_INTERVAL

  RX_BYTES_AFTER=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes)
  TX_BYTES_AFTER=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes)

  echo "RX Bytes after: $RX_BYTES_AFTER"
  echo "TX Bytes after: $TX_BYTES_AFTER"

  # Calculate throughput in Mbps
  RX_BYTES_DELTA=$((RX_BYTES_AFTER - RX_BYTES_BEFORE))
  TX_BYTES_DELTA=$((TX_BYTES_AFTER - TX_BYTES_BEFORE))
  echo "RX Bytes delta: $RX_BYTES_DELTA"
  echo "TX Bytes delta: $TX_BYTES_DELTA"

  if [ $SLEEP_INTERVAL -gt 0 ]; then
      RX_MBPS=$(echo "scale=2; $RX_BYTES_DELTA * 8 / $SLEEP_INTERVAL / 1000000" | bc)
      TX_MBPS=$(echo "scale=2; $TX_BYTES_DELTA * 8 / $SLEEP_INTERVAL / 1000000" | bc)

      echo "RX Throughput: $RX_MBPS Mbps"
      echo "TX Throughput: $TX_MBPS Mbps"

      if (( $(echo "$RX_MBPS > $NETWORK_THRESHOLD_MBPS" | bc -l) )) || (( $(echo "$TX_MBPS > $NETWORK_THRESHOLD_MBPS" | bc -l) )); then
          echo "Network usage is above threshold."
          NETWORK_COUNT=$((NETWORK_COUNT + 1))
      else
          NETWORK_COUNT=0
      fi
  else
      echo "Sleep interval is zero or negative, cannot calculate throughput."
  fi
else
  echo "No suitable network interface found."
  NETWORK_COUNT=0
fi

echo "$CPU_COUNT $MEMORY_COUNT $NETWORK_COUNT" > "$METRIC_FILE"


if [ "$CPU_COUNT" -ge 5 ]; then
  echo "CPU usage is above threshold."
  CPU_TOP=$(ps aux --sort=-%cpu | head -n 4 | tail -n 3 | awk 'BEGIN {print "\n"} {printf "| PID: %-8s | CPU Usage: %-6s%% | Command: %-20s |\n", $2, $3, $11}')
  CPU_TOP_ESCAPED=$(escape_markdownv2 "$CPU_TOP")
  CPU_MESSAGE=$(escape_markdownv2 "High CPU Usage on $SERVER_IP : $CPU_USAGE% ")"\`\`\` PID | CPU Usage | Command $CPU_TOP_ESCAPED\`\`\`"
  echo "$CPU_MESSAGE"
  send_telegram_message "$CPU_MESSAGE"
else
  echo "CPU usage is below threshold."
fi

# Check Memory usage
if [ "$MEMORY_COUNT" -ge 5 ]; then
  echo "Memory usage is above threshold."
  MEMORY_TOP=$(ps aux --sort=-%mem | head -n 4 | tail -n 3 | awk 'BEGIN {print "\n"} {printf "| PID: %-8s | Memory Usage: %-6s%% | Command: %-20s |\n", $2, $4, $11}')
  MEMORY_TOP_ESCAPED=$(escape_markdownv2 "$MEMORY_TOP")
  MEMORY_MESSAGE=$(escape_markdownv2 "High Memory Usage on $SERVER_IP : $MEMORY_USAGE%")"\`\`\` PID  | Memory Usage | Command  $MEMORY_TOP_ESCAPED\`\`\`"
  echo "$MEMORY_MESSAGE"
  send_telegram_message "$MEMORY_MESSAGE"
else
  echo "Memory usage is below threshold."
fi

# Check Network usage
echo "Checking Network usage..."
if [ "$NETWORK_COUNT" -ge 5 ]; then
  NETWORK_MESSAGE=$(escape_markdownv2 "High Network Usage on $SERVER_IP ")"\`\`\` Receiving : $RX_MBPS Mbps - Transfer out : $TX_MBPS Mbps \`\`\`"
  echo "$NETWORK_MESSAGE"
  send_telegram_message "$NETWORK_MESSAGE"
  NETWORK_COUNT=0
fi

# Check Disk space
echo "Checking Disk space..."
DISK_USAGE=$(df / | grep / | awk '{print $5}' | sed 's/%//g')
echo "Current Disk Usage: $DISK_USAGE%"
if [ $DISK_USAGE -ge $DISK_THRESHOLD ]; then
  echo "Disk usage is above threshold."
  DISK_TOP=$(du -ahx / | sort -rh | head -n 3 | awk 'BEGIN {print "\n"} {printf "| %s |\n", $0}')
  DISK_TOP_ESCAPED=$(escape_markdownv2 "$DISK_TOP")
  DISK_MESSAGE=$(escape_markdownv2 "Low Disk Space on $SERVER_IP : $DISK_USAGE% used on /")"\`\`\` Size and Path    $DISK_TOP_ESCAPED\`\`\`"
  echo "$DISK_MESSAGE"
  send_telegram_message "$DISK_MESSAGE"
else
  echo "Disk usage is below threshold."
fi
