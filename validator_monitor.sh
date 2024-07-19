#!/bin/bash

source $HOME/.env
validator_endpoint="http://127.0.0.1:26657/status"
API_URL="https://api.telegram.org/bot${BOT_TOKEN}/sendMessage"
cached_height_file="block_height.txt"
remote_rpcs=(
    "https://rpc-1.celestia.nodes.guru"
    "https://celestia-rpc.lavenderfive.com"
    "https://celestia-mainnet-rpc.itrocket.net"
)

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

get_block_height() {
    local attempts=0
    local max_attempts=3
    while [ $attempts -lt $max_attempts ]; do
        local height=$(curl -s -m 10 -X GET $validator_endpoint -H "Content-Type: application/json" | jq -r ".result.sync_info.latest_block_height")
        if [[ "$height" =~ ^[0-9]+$ ]]; then
            echo "$height"
            return 0
        fi
        attempts=$((attempts + 1))
        echo "Attempt $attempts failed to fetch valid block height. Retrying..."
        sleep 5
    done
    echo ""
    return 1
}

get_remote_height() {
    local rpc_url="$1"
    local remote_height=$(curl -s -m 10 -X GET "$rpc_url/status" -H "Content-Type: application/json" | jq -r ".result.sync_info.latest_block_height")
    if [[ "$remote_height" =~ ^[0-9]+$ ]]; then
        echo "$remote_height"
    else
        echo ""
    fi
}

restart_service() {
    echo "Restarting celestia-appd service"
    sudo service celestia-appd restart
    echo "Waiting for 2 minutes after service restart"
    sleep 120  # Wait for 2 minutes after the service restart
    send_telegram_message "Validator service restarted on $SERVER_IP. Waited for 2 minutes."
    echo "Service restart complete"
}

main() {
    echo "Starting validator monitor script"
    current_height=$(get_block_height)
    if [[ ! "$current_height" =~ ^[0-9]+$ ]]; then
        echo "Failed to obtain valid block height after multiple attempts. Restarting service."
        restart_service
        return
    fi

    echo "Current height: $current_height"

    if [ ! -f "$cached_height_file" ]; then
        echo "$current_height" > "$cached_height_file"
        echo "Initial block height cached: $current_height"
        return
    fi

    previous_height=$(cat "$cached_height_file")
    if [[ ! "$previous_height" =~ ^[0-9]+$ ]]; then
        echo "Invalid previous height found. Updating with current height."
        echo "$current_height" > "$cached_height_file"
        return
    fi

    echo "Previous height: $previous_height"

    if [ "$current_height" -le "$previous_height" ]; then
        echo "Block height has not increased. Checking remote RPCs."
        valid_remote_checks=0
        for rpc in "${remote_rpcs[@]}"; do
            remote_height=$(get_remote_height "$rpc")
            if [[ "$remote_height" =~ ^[0-9]+$ ]]; then
                valid_remote_checks=$((valid_remote_checks + 1))
                if [ "$remote_height" -gt "$((current_height + 4))" ]; then
                    echo "Remote height ($remote_height) from $rpc is more than 4 blocks ahead. Restarting service."
                    restart_service
                    return
                else
                    echo "Remote height ($remote_height) from $rpc is not more than 4 blocks ahead of current height ($current_height)."
                fi
            else
                echo "Failed to get valid remote height from $rpc."
            fi
        done

        if [ $valid_remote_checks -eq 0 ]; then
            echo "Warning: Failed to get valid height from any remote RPC. Network issues?"
            return
        fi

        message="VALIDATOR NODE WARNING""\`\`\` Validator node block height has not increased on $SERVER_IP : Current height: $current_height\`\`\`"
        send_telegram_message "$message"
        echo "Sent warning message to Telegram"
    else
        echo "Block height has increased"
    fi

    echo "$current_height" > "$cached_height_file"
    echo "Updated cached block height: $current_height"
    echo "Validator monitor script completed successfully"
}

{
    main
} || {
    # If an error occurs, send to telegram
    echo "Validator node monitor script crashed."
    send_telegram_message "Validator node monitor script crashed , server ip : $SERVER_IP"
}