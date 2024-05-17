**This script will monitor CPU, Memory , Disk space and network.**

*Threshold is 85% for all , if above threshole then send alert to telegram bot.*

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
