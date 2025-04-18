# bitaxe-power-analysis
Bash script to monitor up to 4 Bitaxe miners, sending power, hashrate, and temp reports to Telegram every 30 minutes.

# Bitaxe Power Analysis

A Bash script to monitor Bitaxe miners, delivering detailed telemetry on power consumption, hashrate, efficiency, and temperatures to Telegram every 30 minutes.

**Repository**: `bitaxe-power-analysis`  
**Description**: Bash script to monitor Bitaxe miners, sending power, hashrate, and temperature reports to Telegram every 30 minutes.  
**License**: MIT License  
**Credits**: Crafted by @chieb_sol vibecoding with @grok

## Overview

The `power_analysis.sh` script monitors up to four Bitaxe miners, fetching real-time metrics via their API and sending formatted reports to a Telegram chat. It logs data in text, CSV, and JSONL formats for analysis and supports log recycling to manage disk space. Designed for 24/7 operation on a Bitcoin node or server, it assumes static IP addresses and basic command-line proficiency.

This script has been tested on a DIY Raspberry Pi 5 (8GB) running Umbrel, ensuring compatibility with lightweight Linux environments.

**Disclaimer**: Use this script at your own risk. The authors assume no liability for any issues arising from its use. Ensure you understand the script’s functionality and test it thoroughly before deployment.

## Prerequisites

Before running `power_analysis.sh`, ensure the following:

- **Hardware**: A Linux-based server or node (e.g., Raspberry Pi 5 with Umbrel) running 24/7.
- **Network**: Static IP addresses for Bitaxe miners, bound via DHCP to ensure consistency.
- **Command-Line Knowledge**: Familiarity with basic Linux commands (e.g., `nano`, `chmod`, `crontab`).
- **Dependencies**:
  - Install `jq`, `curl`, and `bc`:
    ```bash
    sudo apt update
    sudo apt install jq curl bc
    ```
  - Verify:
    ```bash
    jq --version
    curl --version
    bc --version
    ```
- **Telegram Setup**: A Telegram account and bot configured for notifications (see below).

## Telegram Setup

The script sends reports to a Telegram chat. Follow these steps to set up your Telegram bot and obtain the necessary credentials.

1. **Create a Telegram Bot**:
   - Open Telegram and message `@BotFather`.
   - Send `/start`, then `/newbot`.
   - Follow prompts to name your bot (e.g., `BitaxeMonitorBot`).
   - Copy the **Bot Token** (e.g., `123456789:ABCDEFGHIJKLMNOPQRSTUVWXYZ`).

2. **Get Your Chat ID**:
   - Message your bot (e.g., `/start`).
   - Forward a message from your bot to `@GetIDsBot` or use an AI assistant with this prompt:
     ```
     I need help getting my Telegram Chat ID for a bot. I’ve created a bot with BotFather and sent it a message. How do I find the Chat ID?
     ```
     - The AI or `@GetIDsBot` will provide your **Chat ID** (e.g., `123456789`).

3. **Test Telegram Connectivity**:
   - Replace `YOUR_BOT_TOKEN` and `YOUR_CHAT_ID` in the command below and run it on your node:
     ```bash
     curl -s -X POST "https://api.telegram.org/botYOUR_BOT_TOKEN/sendMessage" -d chat_id="YOUR_CHAT_ID" -d text="Test from my node"
     ```
   - Check your Telegram chat for the test message. If it fails, verify your token, chat ID, and network connectivity.

## Script Configuration

The `power_analysis.sh` script requires configuration of user-defined variables to match your setup.

### Key Variables
Edit `power_analysis.sh` using a text editor (e.g., `nano power_analysis.sh`):

- **Miner Settings**:
  - `UserMiners`: Number of miners to monitor (1–4).
  - `MinerIPAddress1`–`MinerIPAddress4`: IP addresses of your Bitaxe miners (e.g., `192.168.1.3`) or `NULL` for unused slots.
  - Example:
    ```bash
    UserMiners=1
    MinerIPAddress1=YOUR_MINER_IP
    MinerIPAddress2=NULL
    MinerIPAddress3=NULL
    MinerIPAddress4=NULL
    ```
- **Telegram Settings**:
  - `TELEGRAM_CHAT_ID`: Your Telegram chat ID (e.g., `YOUR_CHAT_ID`).
  - `TELEGRAM_BOT_TOKEN`: Your Telegram bot token (e.g., `YOUR_BOT_TOKEN`).
  - Example:
    ```bash
    TELEGRAM_CHAT_ID="YOUR_CHAT_ID"
    TELEGRAM_BOT_TOKEN="YOUR_BOT_TOKEN"
    ```
- **Attachment Settings**:
  - `ATTACH_*`: Set to `YES` to attach logs to Telegram messages, `NO` to disable (e.g., `ATTACH_POWER_ANALYSIS_LOG="YES"`).
  - Warning: Attached logs must stay under 50 MB (Telegram limit). Use recycling periods of 336 hours or less.
- **Recycling Periods**:
  - `RECYCLE_*_HOURS`: Hours before truncating logs (e.g., `RECYCLE_POWER_ANALYSIS_HOURS=336` for 14 days).

### Log Files
Logs are stored in `~/logs/power_analysis/<sanitized_IP>/` (e.g., `~/logs/power_analysis/192_168_1_106/`), where `<sanitized_IP>` is the miner’s IP with dots replaced by underscores. Files include:
- `power_analysis.log`: Human-readable metrics (hashrate, efficiency, temperatures).
- `power_metrics.csv`: CSV with metrics for analysis.
- `power_metrics.jsonl`: JSONL for structured data.
- `frequency_voltage_temps.csv`: CSV for charting frequency, voltage, and temps.
- `power_analysis_error.log`: Error messages for troubleshooting.
- Reset files (e.g., `power_analysis_reset.txt`): Track log recycling.

#### CSV and JSONL Files
The `power_analysis.sh` script generates three structured data files—two CSV files (`power_metrics.csv`, `frequency_voltage_temps.csv`) and one JSONL file (`power_metrics.jsonl`)—stored in `~/logs/power_analysis/<sanitized_IP>/` for each miner. These files are designed for advanced users who want to analyze, visualize, or integrate Bitaxe telemetry data into external tools (e.g., spreadsheets, databases, or charting software).

- **`power_metrics.csv`**:
  - **Purpose**: A comma-separated values (CSV) file containing comprehensive miner metrics for each run, ideal for data analysis in spreadsheets (e.g., Excel, Google Sheets) or scripts.
  - **Contents**: Each row represents a single run (every 30 minutes by default) with the following columns:
    - `timestamp`: UTC timestamp (e.g., `2025-04-18T12:00:00Z`).
    - `board_power`: Power consumption in watts (W).
    - `hashrate_ths`: Hashrate in terahashes per second (TH/s).
    - `efficiency`: Efficiency in joules per terahash (J/TH).
    - `asic_temp`: ASIC temperature in °C.
    - `vreg_temp`: Voltage regulator temperature in °C.
    - `ambient_temp`: Ambient temperature in °C (from Open-Meteo API).
    - `frequency`: ASIC frequency in MHz.
    - `core_voltage`: Core voltage in mV.
    - `uptime_seconds`: Miner uptime in seconds.
    - `shares_accepted`: Number of accepted shares.
    - `shares_rejected`: Number of rejected shares.
    - `best_diff`: Best difficulty (all-time).
    - `best_session_diff`: Best difficulty since boot.
  - **Use Case**: Import into a spreadsheet to track performance trends (e.g., hashrate vs. temperature) or analyze efficiency over time. Example:
    ```csv
    timestamp,board_power,hashrate_ths,efficiency,asic_temp,vreg_temp,ambient_temp,frequency,core_voltage,uptime_seconds,shares_accepted,shares_rejected,best_diff,best_session_diff
    2025-04-18T12:00:00Z,100,5.23,19.12,45.5,60.2,20.1,400,1200,3600,150,2,1.2M,500K
    ```
  - **Analysis**: Plot hashrate vs. power to optimize miner settings or detect anomalies (e.g., overheating).

- **`power_metrics.jsonl`**:
  - **Purpose**: A JSON Lines (JSONL) file with the same metrics as `power_metrics.csv`, formatted for programmatic access in databases, data pipelines, or custom applications.
  - **Contents**: Each line is a JSON object with the same fields as `power_metrics.csv` (timestamp, board_power, hashrate_ths, etc.). This format is ideal for tools that parse structured data (e.g., Python, Node.js).
  - **Use Case**: Feed into a time-series database (e.g., InfluxDB) for real-time monitoring or process with scripts for automated alerts. Example:
    ```json
    {"timestamp":"2025-04-18T12:00:00Z","board_power":100,"hashrate_ths":5.23,"efficiency":19.12,"asic_temp":45.5,"vreg_temp":60.2,"ambient_temp":20.1,"frequency":400,"core_voltage":1200,"uptime_seconds":3600,"shares_accepted":150,"shares_rejected":2,"best_diff":"1.2M","best_session_diff":"500K"}
    ```
  - **Analysis**: Use for advanced integrations, such as dashboards (e.g., Grafana) or machine learning models to predict miner performance.

- **`frequency_voltage_temps.csv`**:
  - **Purpose**: A CSV file focused on frequency, voltage, and temperature metrics, optimized for generating charts or monitoring thermal performance.
  - **Contents**: Each row includes:
    - `timestamp`: UTC timestamp.
    - `frequency`: ASIC frequency in MHz.
    - `core_voltage`: Core voltage in mV.
    - `asic_temp`: ASIC temperature in °C.
    - `vreg_temp`: Voltage regulator temperature in °C.
    - `ambient_temp`: Ambient temperature in °C.
  - **Use Case**: Visualize temperature trends vs. frequency or voltage in charting tools (e.g., Excel, Plotly) to optimize miner cooling or detect thermal throttling. Example:
    ```csv
    timestamp,frequency,core_voltage,asic_temp,vreg_temp,ambient_temp
    2025-04-18T12:00:00Z,400,1200,45.5,60.2,20.1
    ```
  - **Analysis**: Create line graphs to correlate frequency with ASIC temperature, helping adjust settings for efficiency.

**Notes**:
- **Storage**: Each file grows with every run (approximately 1.21 MB over 14 days for one miner at 30-minute intervals). Adjust `RECYCLE_*_HOURS` (default: 336 hours) to manage disk space.
- **Access**: Use `cat`, `less`, or spreadsheet software to view files. For JSONL, parse with tools like `jq`:
  ```bash
  cat ~/logs/power_analysis/192_168_1_106/power_metrics.jsonl | jq .

## Installation

1. **Download the Script**:
   - Clone or download `power_analysis.sh` from this repository.
   - Example (if cloning):
     ```bash
     git clone https://github.com/your-username/bitaxe-power-analysis.git
     cd bitaxe-power-analysis
     ```

2. **Make Executable**:
   ```bash
   chmod +x power_analysis.sh
