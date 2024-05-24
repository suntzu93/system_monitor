**This script will monitor CPU, Memory , Disk space and network.**

```
System monitor set threshold is 85% for all , if above threshole then send alert to telegram bot.*
Bridge monitor will send notification via telegram when block height not increase after 1 minute.*
Valiadtor monitor will send notification via telegram when block height not increase after 1 minute.
```

Add telegram config in .env :

```
BOT_TOKEN="xxx"
CHAT_ID=xxx
```

To get chat_id :

```
Send a message to telegram bot.

Get the list of updates for your BOT:

https://api.telegram.org/bot<YourBOTToken>/getUpdates
```

How to run :

```
cd $HOME
wget https://raw.githubusercontent.com/suntzu93/system_monitor/main/system_monitor.sh
chmod +x system_monitor.sh
# Add to crontab , script will run each minutes 

CRON_JOB="* * * * * $HOME/system_monitor.sh >> /var/log/system_monitor.log 2>&1"
(crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

# run on bridge node server
wget https://raw.githubusercontent.com/suntzu93/system_monitor/main/bridge_monitor.sh
chmod +x bridge_monitor.sh

CRON_JOB_BRIDGE="* * * * * $HOME/bridge_monitor.sh >> /var/log/bridge_monitor.log 2>&1"
(crontab -l 2>/dev/null; echo "$CRON_JOB_BRIDGE") | crontab -

# run on validator node server
wget https://raw.githubusercontent.com/suntzu93/system_monitor/main/validator_monitor.sh
chmod +x bridge_monitor.sh

CRON_JOB_VALIDATOR="* * * * * $HOME/validator_monitor.sh >> /var/log/validator_monitor.log 2>&1"
(crontab -l 2>/dev/null; echo "$CRON_JOB_VALIDATOR") | crontab -




```
