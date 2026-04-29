Bitaxe Power Analysis
A Bash script to monitor up to 4 Bitaxe miners, delivering detailed telemetry on power consumption, hashrate, efficiency, and temperatures to Telegram every 30 minutes.
Repository: bitaxe-power-analysis
License: MIT License
Credits: Crafted by @chieb_sol vibecoding with Claude and @grok

Table of Contents

Overview
Supported Hardware
Prerequisites
Telegram Setup
Installation
Configuration
Testing
Setting Up a Cron Job
Umbrel Upgrade Warning
Log Files
Version History
Notes
License


Overview
The power_analysisv1.sh script monitors up to four Bitaxe miners, fetching real-time metrics via their API and sending formatted reports to a Telegram chat every 30 minutes. It logs data in text, CSV, and JSONL formats for analysis and supports automatic log recycling to manage disk space.
Designed for 24/7 operation on a Bitcoin node or home server. Tested on a DIY Raspberry Pi 5 (8GB) running Umbrel, ensuring compatibility with lightweight Linux environments.
Example Telegram Report:
📊 30mins Report Card 📊

⛏️ Miner: bitaxegammacbs
🌐 IP Address: 192.168.1.106
🕒 Uptime: 12h 34m 56s
🔋 Board Power:  24.80W
⚙️ Frequency:  762.5 MHz
🔧 Core Voltage:  1230 mV
──────────────
🤖 Hashrate:   1.20 TH/s
💡 Efficiency:  20.67 J/TH
🌡️ Ambient Temp:  12.50°C
🔥 ASIC Temp:  52.00°C
🔌 Vol Reg Temp:  45.00°C
💨 Fan Speed:  62.00%
──────────────
⭐ BestDiff: 9.2G
🌟 DiffBoot: 4.2M
📈 Shares: 842
⏳ AvgShares/hr:  67.54
🏊 Pool: public-pool.io
📊 Pool Difficulty: 50000
💰 Wallet: YOUR_BITCOIN_ADDRESS

🕒 Time: 08:30:00 UTC
📅 Date: Tue Apr 29 2026

Supported Hardware
DeviceSupportedNotesBitaxe Gamma✅Fully supportedNerdQAxe++✅Requires firmware v1.0.30 or later

⚠️ NerdQAxe++ firmware warning: Earlier versions do not expose poolDifficulty via the API, which is required for correct pool stats. Ensure firmware is v1.0.30 or higher before use.

The script automatically detects the device model and retrieves pool difficulty accordingly:

Uses poolDifficulty for NerdQAxe++
Falls back to stratumDiff for Bitaxe Gamma


Prerequisites

Hardware: A Linux-based server or node (e.g., Raspberry Pi 5 with Umbrel) running 24/7
Network: Static IP addresses for Bitaxe miners, bound via DHCP reservation
Command-Line Knowledge: Familiarity with basic Linux commands (nano, chmod, crontab)

Install Dependencies
bashsudo apt update && sudo apt install -y jq curl bc cron
Verify:
bashjq --version && curl --version && bc --version
Enable and start cron:
bashsudo systemctl enable cron
sudo systemctl start cron

Telegram Setup

Create a Telegram Bot:

Open Telegram and message @BotFather
Send /start, then /newbot
Follow the prompts and copy the Bot Token


Get Your Chat ID:

Message your bot (e.g., /start)
Forward a message from your bot to @GetIDsBot to retrieve your Chat ID


Test Telegram Connectivity:

bashcurl -s -X POST "https://api.telegram.org/botYOUR_BOT_TOKEN/sendMessage" \
  -d chat_id="YOUR_CHAT_ID" \
  -d text="Test from my node"
Check your Telegram chat for the test message.

Installation

Clone the repository:

bashgit clone https://github.com/chiefbsol-cloud/bitaxe-power-analysis.git
cd bitaxe-power-analysis
Or download power_analysisv1.sh directly and place it in your home directory (~/).

Make executable:

bashchmod +x ~/power_analysisv1.sh

Create log directories:

bashmkdir -p ~/logs/power_analysis

Configuration
Edit the script:
bashnano ~/power_analysisv1.sh
Key Variables
VariableDescriptionExampleUserMinersNumber of miners to monitor (1–4)2MinerIPAddress1–4IP addresses of miners, or NULL192.168.1.106TELEGRAM_CHAT_IDYour Telegram chat IDYOUR_TELEGRAM_CHAT_IDTELEGRAM_BOT_TOKENYour Telegram bot tokenYOUR_TELEGRAM_BOT_TOKENLATITUDE / LONGITUDEYour location for ambient temperature55.8642 / -4.2518VREG_TEMP_LIMITVReg temperature alert threshold (°C)65RECYCLE_*_HOURSHours before log truncation336 (14 days)ATTACH_*Attach log files to Telegram (YES/NO)NO

🔒 Security: Never commit your real TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID to a public repository. Use placeholders in shared files.


Testing
Run manually:
bashbash ~/power_analysisv1.sh
Check Telegram for a report. If it doesn't arrive, check the error log:
bashcat ~/logs/power_analysis/192_168_1_106/power_analysis_error.log
Common issues:

API failure: Verify miner is reachable — curl -s http://YOUR_MINER_IP/api/system/info | jq .
Telegram failure: Re-run the connectivity test above
Missing dependencies: Re-run the install command


Setting Up a Cron Job
bashcrontab -e
Add:
*/30 * * * * /bin/bash /home/umbrel/power_analysisv1.sh >> /home/umbrel/logs/power_analysis/cron.log 2>&1
Verify:
bashcrontab -l

ℹ️ The script runs every 30 minutes. Adjust the path if your script is in a different location.


Umbrel Upgrade Warning

⚠️ Umbrel OS upgrades (e.g., to v1.7) will wipe your cron jobs and may remove installed dependencies.

After any Umbrel upgrade, run the following recovery steps:
bash# 1. Reinstall dependencies
sudo apt update && sudo apt install -y jq curl bc cron

# 2. Enable cron
sudo systemctl enable cron && sudo systemctl start cron

# 3. Re-add umbrel to docker group (required for block-analysis-tool)
sudo usermod -aG docker umbrel

# 4. Recreate log directories
mkdir -p ~/logs/power_analysis
mkdir -p ~/logs/block_delay

# 5. Re-register cron jobs
crontab -e
Log out and back in via SSH after step 3 for the docker group change to take effect.

Log Files
Logs are stored per miner in ~/logs/power_analysis/<sanitized_IP>/ (e.g., ~/logs/power_analysis/192_168_1_106/).
FileDescriptionpower_analysis.logHuman-readable metrics per runpower_metrics.csvFull metrics in CSV format for spreadsheet analysispower_metrics.jsonlStructured JSONL for databases or dashboards (e.g., Grafana)frequency_voltage_temps.csvFrequency, voltage, and temperature data for chartingpower_analysis_error.logError messages for troubleshooting
Logs recycle every 336 hours (14 days) by default. Adjust RECYCLE_*_HOURS in the script if needed.

Version History
power_analysisv1.sh (current)

✅ Added format_diff() — BestDiff and DiffBoot now display in shorthand (e.g., 9.2G, 4.2M, 847K)
✅ Frequency now displays with 1 decimal place (e.g., 762.5 MHz)
✅ Wallet address field — reads live from stratumUser API field, displayed in Telegram report for at-a-glance verification
✅ Credits updated to include Claude

power_analysis.sh (original)

Initial release supporting Bitaxe Gamma and NerdQAxe++
30-minute Telegram reports with power, hashrate, efficiency, and temperature data


Notes

Static IPs: Ensure miners have fixed IPs via DHCP reservation to prevent connection failures
Disk space: Each miner generates ~1.21 MB of logs over 14 days at 30-minute intervals
Ambient temperature: Uses the free Open-Meteo API — no API key required
Wallet verification: The 💰 Wallet field in the Telegram report reads directly from the miner's stratumUser setting, making it easy to spot any unexpected changes


License
This project is licensed under the MIT License. See the LICENSE file for details.

Contact
For questions or contributions, open a GitHub issue or message @chieb_sol on Telegram.
