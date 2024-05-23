#!/bin/bash

source  $HOME/.env
url="http://127.0.0.1:26658"
API_URL="https://api.telegram.org/bot${BOT_TOKEN}/sendMessage"
cached_height_file="block_height.txt"
AUTH_TOKEN=$(/usr/local/bin/celestia bridge auth admin --p2p.network celestia)

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
    curl -s -X POST $url \
         -H "Content-Type: application/json" \
         -H "Authorization: Bearer $AUTH_TOKEN" \
         -d '{
             "id": 1,
             "jsonrpc": "2.0",
             "method": "header.NetworkHead",
             "params": []
         }' | jq -r ".result.header.height"
}

main(){
    # Check if AUTH_TOKEN is not empty
    if [ -z "$AUTH_TOKEN" ]; then
        echo "Failed to obtain AUTH_TOKEN"
        send_telegram_message "Failed to obtain AUTH_TOKEN"
        sleep 60
    fi

    current_height=$(get_block_height || echo "")
    echo "current_height : " $current_height
    if [ -z "$current_height" ]; then
        echo "Failed to obtain block height"
        message="NODE WARNING ""\`\`\` Bridge node crashed , cannot get header height on $SERVER_IP\`\`\`"
        send_telegram_message "$message"

    fi
    if [ ! -f "$cached_height_file" ]; then
        echo "$current_height" > "$cached_height_file"
        echo "Initial block height cached: $current_height"
    else
        previous_height=$(cat "$cached_height_file")
        if [ "$current_height" -le "$previous_height" ]; then
            message="NODE WARNING ""\`\`\` Block height has not increased on $SERVER_IP : Current height: $current_height\`\`\`"
            send_telegram_message "$message"
        fi
        echo "$current_height" > "$cached_height_file"
    fi
}

{
    main
} || {
    # If an error occurs, send to telegram
    echo "Bridge node monitor script crashed."
    send_telegram_message "Bridge node monitor script crashed , server ip : $SERVER_IP"
}
