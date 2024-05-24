#!/bin/bash

source  $HOME/.env
validator_endpoint="http://127.0.0.1:26657/status"
API_URL="https://api.telegram.org/bot${BOT_TOKEN}/sendMessage"
cached_height_file="block_height.txt"

get_server_ip() {
  local ip
  ip=$(hostname -I | awk '{print $1}')
  echo "$ip"
}

SERVER_IP=$(get_server_ip)
echo "Server IP: $SERVER_IP"

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

# Function to get block height
get_block_height() {
    curl -s -X GET $validator_endpoint \
         -H "Content-Type: application/json"  | jq -r ".result.sync_info.latest_block_height"
}

main(){
    current_height=$(get_block_height || echo "")
    echo "current_height : " $current_height
    if [ -z "$current_height" ]; then
        echo "Failed to obtain block height"
        message="VALIDATOR WARNING""\`\`\` VALIDATOR node crashed , cannot get header height on $SERVER_IP\`\`\`"
        send_telegram_message "$message"

    fi
    if [ ! -f "$cached_height_file" ]; then
        echo "$current_height" > "$cached_height_file"
        echo "Initial block height cached: $current_height"
    else
        previous_height=$(cat "$cached_height_file")
        if [ "$current_height" -le "$previous_height" ]; then
            message="VALIDATOR NODE WARNING""\`\`\` Validator node block height has not increased on $SERVER_IP : Current height: $current_height\`\`\`"
            send_telegram_message "$message"
        fi
        echo "$current_height" > "$cached_height_file"
    fi
}

{
    main
} || {
    # If an error occurs, send to telegram
    echo "Validator node monitor script crashed."
    send_telegram_message "Validator node monitor script crashed , server ip : $SERVER_IP"
}
