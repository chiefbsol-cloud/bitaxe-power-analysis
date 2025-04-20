#!/bin/bash -l

set -euo pipefail  # Stricter error handling

# Credit Header
# Crafted by @chieb_sol vibecoding with @grok
# V2 with minor updates to display Board Power and Pool

# Set PATH for cron
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH

# Configuration
# Miner Settings
UserMiners=1  # Number of miners to monitor (1-4)
MinerIPAddress1=YOUR_MINER_IP  # IP address of miner 1 or NULL
MinerIPAddress2=NULL           # IP address of miner 2 or NULL
MinerIPAddress3=NULL           # IP address of miner 3 or NULL
MinerIPAddress4=NULL           # IP address of miner 4 or NULL

# General Settings
TELEGRAM_CHAT_ID="YOUR_CHAT_ID"
TELEGRAM_BOT_TOKEN="YOUR_BOT_TOKEN"
VREG_TEMP_LIMIT=65  # Voltage regulator temp limit (°C)
DEBUG=false  # Set to true for console output

# Telegram Attachment Settings (YES/NO)
# Set to YES to attach the log file to Telegram messages, NO to disable.
# Warning: Attached files must stay under 50 MB (Telegram limit). Use recycling periods
# of 336 hours (14 days) or less for attached logs to manage file sizes. Disabling
# attachments for unneeded logs reduces Telegram chat clutter.
ATTACH_POWER_ANALYSIS_LOG="NO"      # Attach power_analysis.log
ATTACH_POWER_METRICS_CSV="NO"       # Attach power_metrics.csv
ATTACH_POWER_METRICS_JSONL="NO"     # Attach power_metrics.jsonl
ATTACH_FREQUENCY_VOLTAGE_TEMPS="NO"  # Attach frequency_voltage_temps.csv

# Log Recycling Periods (hours, 0 to disable)
# Set the number of hours after which each log is truncated. Use 336 hours (14 days) or
# less for logs attached to Telegram to avoid exceeding the 50 MB file size limit.
# Disabling recycling (0) may cause large files and disk space issues.
# Valid values: 0 (disable) or positive integers.
RECYCLE_POWER_ANALYSIS_HOURS=336          # Recycle power_analysis.log
RECYCLE_POWER_METRICS_CSV_HOURS=336       # Recycle power_metrics.csv
RECYCLE_POWER_METRICS_JSONL_HOURS=336     # Recycle power_metrics.jsonl
RECYCLE_FREQUENCY_VOLTAGE_TEMPS_HOURS=336 # Recycle frequency_voltage_temps.csv

# Define TIMESTAMP globally
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Function to check dependencies
check_dependencies() {
  for cmd in jq curl bc; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "[$TIMESTAMP] Error: $cmd is required but not found in PATH ($PATH)." >&2
      send_telegram_message "❌ Error: $cmd not found at $(date -u)!" "/tmp/power_analysis_error.log"
      exit 1
    fi
  done
}

# Function to send Telegram message
send_telegram_message() {
  local message="$1"
  local error_log="$2"
  echo "[$TIMESTAMP] Sending Telegram message at $(date -u)" >>"$error_log"
  curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
    -d chat_id="$TELEGRAM_CHAT_ID" \
    -d parse_mode="HTML" \
    -d text="$message" >>"$error_log" 2>&1
  local curl_exit_code=$?
  echo "[$TIMESTAMP] curl exit code for sendMessage: $curl_exit_code" >>"$error_log"
  if [ $curl_exit_code -ne 0 ]; then
    echo "[$TIMESTAMP] Failed to send Telegram message at $(date -u)" >>"$error_log"
  fi
}

# Function to send Telegram document
send_telegram_document() {
  local file="$1"
  local error_log="$2"
  echo "[$TIMESTAMP] Sending Telegram document: $file at $(date -u)" >>"$error_log"
  curl -s -F document=@"$file" \
    "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendDocument?chat_id=$TELEGRAM_CHAT_ID" >>"$error_log" 2>&1
  local curl_exit_code=$?
  echo "[$TIMESTAMP] curl exit code for sendDocument: $curl_exit_code" >>"$error_log"
  if [ $curl_exit_code -ne 0 ]; then
    echo "[$TIMESTAMP] Failed to send Telegram document $file at $(date -u)" >>"$error_log"
  fi
}

# Function to recycle logs
recycle_logs() {
  local log_dir="$1"
  local error_log="$2"
  local current_time=$(date +%s)
  local hours_since_reset last_reset

  # Helper function to recycle a log
  recycle_log() {
    local log_file="$1"
    local reset_file="$2"
    local recycle_hours="$3"
    if [ "$recycle_hours" -gt 0 ]; then
      last_reset=$(cat "$reset_file" 2>/dev/null || echo 0)
      hours_since_reset=$(( (current_time - last_reset) / 3600 ))
      if [ "$hours_since_reset" -ge "$recycle_hours" ]; then
        if [ -f "$log_file" ]; then
          : > "$log_file"
          echo "[$TIMESTAMP] Recycled $log_file (age: $hours_since_reset hours)" >>"$error_log"
        fi
        echo "$current_time" > "$reset_file"
      fi
    fi
  }

  # Validate recycling periods
  for period in "$RECYCLE_POWER_ANALYSIS_HOURS" "$RECYCLE_POWER_METRICS_CSV_HOURS" \
                "$RECYCLE_POWER_METRICS_JSONL_HOURS" "$RECYCLE_FREQUENCY_VOLTAGE_TEMPS_HOURS"; do
    if ! [[ "$period" =~ ^[0-9]+$ ]]; then
      echo "[$TIMESTAMP] Warning: Invalid recycling period ($period). Using 336 hours." >>"$error_log"
      period=336
    fi
  done

  # Recycle each log
  recycle_log "$log_dir/power_analysis.log" "$log_dir/power_analysis_reset.txt" "$RECYCLE_POWER_ANALYSIS_HOURS"
  recycle_log "$log_dir/power_metrics.csv" "$log_dir/power_metrics_csv_reset.txt" "$RECYCLE_POWER_METRICS_CSV_HOURS"
  recycle_log "$log_dir/power_metrics.jsonl" "$log_dir/power_metrics_jsonl_reset.txt" "$RECYCLE_POWER_METRICS_JSONL_HOURS"
  recycle_log "$log_dir/frequency_voltage_temps.csv" "$log_dir/frequency_voltage_temps_reset.txt" "$RECYCLE_FREQUENCY_VOLTAGE_TEMPS_HOURS"
}

# Function to collect data
collect_data() {
  local api_url="$1"
  local error_log="$2"

  # Fetch data from Bitaxe API
  API_DATA=$(curl -s --connect-timeout 10 "$api_url" 2>>"$error_log")
  if [ -z "$API_DATA" ]; then
    echo "[$TIMESTAMP] Error: Failed to fetch data from Bitaxe API ($api_url)." >>"$error_log"
    send_telegram_message "❌ Error: Failed to fetch Bitaxe API data from $api_url at $TIMESTAMP!" "$error_log"
    return 1
  fi

  # Extract fields
  HOSTNAME=$(echo "$API_DATA" | jq -r '.hostname // "N/A"')
  BOARD_POWER=$(echo "$API_DATA" | jq -r '.power // "N/A"')
  HASH_RATE=$(echo "$API_DATA" | jq -r '.hashRate // "N/A"')
  ASIC_TEMP=$(echo "$API_DATA" | jq -r '.temp // "N/A"')
  VREG_TEMP=$(echo "$API_DATA" | jq -r '.vrTemp // "N/A"')
  FAN_SPEED_PERCENT=$(echo "$API_DATA" | jq -r '.fanspeed // "N/A"')
  FREQUENCY=$(echo "$API_DATA" | jq -r '.frequency // "N/A"')
  CORE_VOLTAGE=$(echo "$API_DATA" | jq -r '.coreVoltage // "N/A"')
  INPUT_VOLTAGE=$(echo "$API_DATA" | jq -r '.voltage // "N/A"')
  MEASURED_ASIC_VOLTAGE=$(echo "$API_DATA" | jq -r '.coreVoltageActual // "N/A"')
  UPTIME_TOTAL_SECONDS=$(echo "$API_DATA" | jq -r '.uptimeSeconds // "N/A"')
  SHARES_ACCEPTED=$(echo "$API_DATA" | jq -r '.sharesAccepted // "N/A"')
  SHARES_REJECTED=$(echo "$API_DATA" | jq -r '.sharesRejected // "N/A"')
  SHARES_REJECTED_REASONS=$(echo "$API_DATA" | jq -r '.sharesRejectedReasons[0].message // "N/A"')
  BEST_DIFF=$(echo "$API_DATA" | jq -r '.bestDiff // "N/A"')
  BEST_SESSION_DIFF=$(echo "$API_DATA" | jq -r '.bestSessionDiff // "N/A"')
  FAN_RPM=$(echo "$API_DATA" | jq -r '.fanrpm // "N/A"')
  POOL_NAME=$(echo "$API_DATA" | jq -r '.stratumURL // "N/A"')
  FALLBACK_POOL_NAME=$(echo "$API_DATA" | jq -r '.fallbackStratumURL // "N/A"')
  IS_USING_FALLBACK=$(echo "$API_DATA" | jq -r '.isUsingFallbackStratum // "N/A"')

  # Determine the active pool based on isUsingFallbackStratum
  if [[ "$IS_USING_FALLBACK" == "1" ]]; then
   POOL_NAME="$FALLBACK_POOL_NAME"
  else
   POOL_NAME=$(echo "$API_DATA" | jq -r '.stratumURL // "N/A"')
fi

  # Convert voltages
  INPUT_VOLTAGE_V="N/A"
  if [[ -n "$INPUT_VOLTAGE" && "$INPUT_VOLTAGE" != "N/A" && "$INPUT_VOLTAGE" != "null" ]]; then
    INPUT_VOLTAGE_V=$(echo "scale=3; $INPUT_VOLTAGE / 1000" | bc -l 2>>"$error_log")
  fi
  MEASURED_ASIC_VOLTAGE_V="N/A"
  if [[ -n "$MEASURED_ASIC_VOLTAGE" && "$MEASURED_ASIC_VOLTAGE" != "N/A" && "$MEASURED_ASIC_VOLTAGE" != "null" ]]; then
    MEASURED_ASIC_VOLTAGE_V=$(echo "scale=3; $MEASURED_ASIC_VOLTAGE / 1000" | bc -l 2>>"$error_log")
  fi

  # Validate critical fields
  for field in HOSTNAME BOARD_POWER HASH_RATE ASIC_TEMP VREG_TEMP FAN_SPEED_PERCENT FREQUENCY CORE_VOLTAGE UPTIME_TOTAL_SECONDS SHARES_ACCEPTED SHARES_REJECTED BEST_DIFF BEST_SESSION_DIFF FAN_RPM POOL_NAME FALLBACK_POOL_NAME IS_USING_FALLBACK; do
    if [[ -z "${!field}" || "${!field}" == "N/A" || "${!field}" == "null" ]]; then
      echo "[$TIMESTAMP] Error: Missing or invalid $field from API ($api_url)." >>"$error_log"
      send_telegram_message "❌ Error: Missing $field from $api_url at $TIMESTAMP!" "$error_log"
      return 1
    fi
  done

  # Convert hash rate to TH/s
  HASH_RATE_THS=$(echo "scale=3; $HASH_RATE / 1000" | bc -l 2>>"$error_log")
  if [[ -z "$HASH_RATE_THS" || "$HASH_RATE_THS" == *"error"* ]]; then
    echo "[$TIMESTAMP] Error: Failed to calculate HASH_RATE_THS." >>"$error_log"
    HASH_RATE_THS="N/A"
    EFFICIENCY="N/A"
  else
    # Calculate efficiency
    if [[ $(echo "$HASH_RATE_THS == 0" | bc -l 2>>"$error_log") -eq 1 ]]; then
      EFFICIENCY="N/A"
    else
      EFFICIENCY=$(echo "scale=2; $BOARD_POWER / $HASH_RATE_THS" | bc -l 2>>"$error_log")
      if [[ -z "$EFFICIENCY" || "$EFFICIENCY" == *"error"* ]]; then
        EFFICIENCY="N/A"
        echo "[$TIMESTAMP] Error: Failed to calculate EFFICIENCY." >>"$error_log"
      fi
    fi
  fi

  # Calculate uptime in hours, minutes, seconds
  if [[ "$UPTIME_TOTAL_SECONDS" =~ ^[0-9]+$ ]]; then
    UPTIME_HOURS=$((UPTIME_TOTAL_SECONDS / 3600))
    UPTIME_MINUTES=$(((UPTIME_TOTAL_SECONDS % 3600) / 60))
    UPTIME_SECONDS_REMAINDER=$((UPTIME_TOTAL_SECONDS % 60))
  else
    UPTIME_HOURS="N/A"
    UPTIME_MINUTES="N/A"
    UPTIME_SECONDS_REMAINDER="N/A"
    AVG_SHARES_PER_HOUR="N/A"
  fi

  # Calculate AvgShares/hr
  AVG_SHARES_PER_HOUR="N/A"
  if [[ "$UPTIME_TOTAL_SECONDS" =~ ^[0-9]+$ && "$UPTIME_TOTAL_SECONDS" -gt 0 && "$SHARES_ACCEPTED" =~ ^[0-9]+$ ]]; then
    AVG_SHARES_PER_HOUR=$(echo "scale=4; ($SHARES_ACCEPTED / $UPTIME_TOTAL_SECONDS) * 3600" | bc -l 2>>"$error_log")
    if [[ -n "$AVG_SHARES_PER_HOUR" && ! "$AVG_SHARES_PER_HOUR" == *"error"* ]]; then
      AVG_SHARES_PER_HOUR=$(printf "%.2f" "$AVG_SHARES_PER_HOUR")
    else
      echo "[$TIMESTAMP] Error: Failed to calculate AVG_SHARES_PER_HOUR (SHARES_ACCEPTED=$SHARES_ACCEPTED, UPTIME_TOTAL_SECONDS=$UPTIME_TOTAL_SECONDS)." >>"$error_log"
      AVG_SHARES_PER_HOUR="N/A"
    fi
  elif [[ "$SHARES_ACCEPTED" =~ ^[0-9]+$ && "$SHARES_ACCEPTED" -eq 0 ]]; then
    AVG_SHARES_PER_HOUR="0.00"
  else
    echo "[$TIMESTAMP] Error: Invalid SHARES_ACCEPTED ($SHARES_ACCEPTED) or UPTIME_TOTAL_SECONDS ($UPTIME_TOTAL_SECONDS)." >>"$error_log"
    AVG_SHARES_PER_HOUR="N/A"
  fi

# User-defined coordinates for ambient temperature (replace with your location, e.g., 51.5074,-0.1278 for Trafalgar Square, London)
LATITUDE="YOUR_LATTITUDE"
LONGITUDE="YOUR_LONGTITUDE"

# Fetch ambient temperature from Open-Meteo API
AMBIENT_TEMP=$(curl -s "https://api.open-meteo.com/v1/forecast?latitude=$LATITUDE&longitude=$LONGITUDE&current=temperature_2m&timezone=UTC" | jq -r '.current.temperature_2m // "N/A"' 2>>"$error_log")
if [[ "$AMBIENT_TEMP" == "N/A" ]]; then
    echo "[$TIMESTAMP] Warning: Failed to fetch ambient temp from Open-Meteo API (latitude=$LATITUDE, longitude=$LONGITUDE)." >>"$error_log"
fi

}

# Function to log data
log_data() {
  local log_dir="$1"
  local error_log="$2"
  local text_log="$log_dir/power_analysis.log"
  local csv_log="$log_dir/power_metrics.csv"
  local jsonl_log="$log_dir/power_metrics.jsonl"
  local chart_csv="$log_dir/frequency_voltage_temps.csv"

  # Create logs if they don't exist
  [ ! -f "$text_log" ] && touch "$text_log"
  [ ! -f "$csv_log" ] && echo "timestamp,board_power,hashrate_ths,efficiency,asic_temp,vreg_temp,ambient_temp,frequency,core_voltage,uptime_seconds,shares_accepted,shares_rejected,best_diff,best_session_diff" > "$csv_log"
  [ ! -f "$jsonl_log" ] && touch "$jsonl_log"
  [ ! -f "$chart_csv" ] && echo "timestamp,frequency,core_voltage,asic_temp,vreg_temp,ambient_temp" > "$chart_csv"

  # Write to text log
  {
    echo "==== Reading at $TIMESTAMP ===="
    echo "Hashrate: $HASH_RATE GH/s ($HASH_RATE_THS TH/s)"
    echo "Efficiency: $EFFICIENCY J/TH"
    echo "Shares: $SHARES_ACCEPTED"
    echo "Shares Not Found: $SHARES_REJECTED"
    echo "Reason for Shares Not Found: $SHARES_REJECTED_REASONS"
    echo "Best Difficulty (All Time): $BEST_DIFF"
    echo "Best Difficulty (Since Boot): $BEST_SESSION_DIFF"
    echo "Uptime: $UPTIME_TOTAL_SECONDS seconds ($UPTIME_HOURS h $UPTIME_MINUTES m $UPTIME_SECONDS_REMAINDER s)"
    echo "Average Shares per Hour: $AVG_SHARES_PER_HOUR"
    echo "----"
    echo "Board Power: $BOARD_POWER W"
    echo "Input Voltage: $INPUT_VOLTAGE_V V"
    echo "ASIC Frequency: $FREQUENCY MHz"
    echo "Core Voltage: $CORE_VOLTAGE mV"
    echo "Measured ASIC Voltage: $MEASURED_ASIC_VOLTAGE_V V"
    echo "----"
    echo "Ambient Temperature: $AMBIENT_TEMP °C"
    echo "ASIC Temperature: $ASIC_TEMP °C"
    echo "Voltage Regulator Temperature: $VREG_TEMP °C"
    echo "Fan Speed: $FAN_SPEED_PERCENT % ($FAN_RPM RPM)"
    if [[ -n "$VREG_TEMP" && "$VREG_TEMP" != "N/A" ]] && (( $(echo "$VREG_TEMP >= $VREG_TEMP_LIMIT" | bc -l 2>>"$error_log") )); then
      echo "WARNING: VReg temp ($VREG_TEMP °C) at or above limit ($VREG_TEMP_LIMIT °C)!"
    fi
    echo "==== End of Reading ===="
  } >> "$text_log"

  # Write to CSV
  echo "$TIMESTAMP,$BOARD_POWER,$HASH_RATE_THS,$EFFICIENCY,$ASIC_TEMP,$VREG_TEMP,$AMBIENT_TEMP,$FREQUENCY,$CORE_VOLTAGE,$UPTIME_TOTAL_SECONDS,$SHARES_ACCEPTED,$SHARES_REJECTED,$BEST_DIFF,$BEST_SESSION_DIFF" >> "$csv_log"

  # Write to JSONL
  echo "{\"timestamp\":\"$TIMESTAMP\",\"board_power\":$BOARD_POWER,\"hashrate_ths\":$HASH_RATE_THS,\"efficiency\":$EFFICIENCY,\"asic_temp\":$ASIC_TEMP,\"vreg_temp\":$VREG_TEMP,\"ambient_temp\":$AMBIENT_TEMP,\"frequency\":$FREQUENCY,\"core_voltage\":$CORE_VOLTAGE,\"uptime_seconds\":$UPTIME_TOTAL_SECONDS,\"shares_accepted\":$SHARES_ACCEPTED,\"shares_rejected\":$SHARES_REJECTED,\"best_diff\":$BEST_DIFF,\"best_session_diff\":$BEST_SESSION_DIFF}" >> "$jsonl_log"

  # Write to charting CSV
  echo "$TIMESTAMP,$FREQUENCY,$CORE_VOLTAGE,$ASIC_TEMP,$VREG_TEMP,$AMBIENT_TEMP" >> "$chart_csv"
}

# Function to format Telegram message
format_telegram_message() {
  local ip="$1"
  # Escape hostname (for HTML compatibility)
  HOSTNAME_ESC=$(echo "$HOSTNAME" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')

 # Escape pool name (for HTML compatibility)
  POOL_NAME_ESC=$(echo "$POOL_NAME" | tr -d '\n' | sed 's/&/\&/g; s/</\</g; s/>/\>/g')

  # Time and date separately
  TIME_NOW=$(date -u +"%H:%M:%S UTC")
  DATE_NOW=$(date -u +"%a %b %d %Y")

  # Format message
  SUMMARY_MESSAGE=$(cat <<EOF
📊 <b>30mins Report Card</b> 📊
<pre>
⛏️ Miner:           $HOSTNAME_ESC
🌐 IP Address:      $ip
🕒 Uptime:          ${UPTIME_HOURS}h ${UPTIME_MINUTES}m ${UPTIME_SECONDS_REMAINDER}s
🔋 Board Power:     $(printf "%6.2f" "$BOARD_POWER")W
🤖 Hashrate:        $(printf "%6.2f" "$HASH_RATE_THS") TH/s
💡 Efficiency:      $(printf "%6.2f" "$EFFICIENCY") J/TH
🌡️ Ambient Temp:    $(printf "%6.2f" "$AMBIENT_TEMP")°C
🔥 ASIC Temp:       $(printf "%6.2f" "$ASIC_TEMP")°C
🔌 Vol Reg Temp:    $(printf "%6.2f" "$VREG_TEMP")°C
💨 Fan Speed:       $(printf "%6.2f" "$FAN_SPEED_PERCENT")%
──────────────
⭐ BestDiff:        $BEST_DIFF
🌟 DiffBoot:        $BEST_SESSION_DIFF
📈 Shares:          $SHARES_ACCEPTED
⏳ AvgShares/hr:    $(printf "%6.2f" "$AVG_SHARES_PER_HOUR")
🏊 Pool:            $POOL_NAME_ESC
</pre>
🕒 <b>Time:</b> $TIME_NOW
📅 <b>Date:</b> $DATE_NOW
EOF
)
}

# Main execution
check_dependencies

# Validate UserMiners
if ! [[ "$UserMiners" =~ ^[1-4]$ ]]; then
  echo "[$TIMESTAMP] Error: Invalid UserMiners ($UserMiners). Must be 1-4." >&2
  send_telegram_message "❌ Error: Invalid UserMiners ($UserMiners) at $TIMESTAMP! Must be 1-4." "/tmp/power_analysis_error.log"
  exit 1
fi

# Process each miner
for ((i=1; i<=UserMiners && i<=4; i++)); do
  ip_var="MinerIPAddress$i"
  ip=${!ip_var}
  
  # Skip NULL or invalid IPs
  if [ "$ip" = "NULL" ] || ! [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    echo "[$TIMESTAMP] Warning: Skipping invalid or NULL IP for Miner $i ($ip)." >&2
    continue
  fi

  # Sanitize IP for directory name (replace dots with underscores)
  ip_sanitized=$(echo "$ip" | tr '.' '_')
  LOG_DIR="$HOME/logs/power_analysis/$ip_sanitized"
  ERROR_LOG="$LOG_DIR/power_analysis_error.log"
  API_URL="http://$ip/api/system/info"

  # Create log directory
  mkdir -p "$LOG_DIR"

  # Recycle logs
  recycle_logs "$LOG_DIR" "$ERROR_LOG"

  # Collect data
  if ! collect_data "$API_URL" "$ERROR_LOG"; then
    echo "[$TIMESTAMP] Skipping Miner $i ($ip) due to data collection failure." >>"$ERROR_LOG"
    continue
  fi

  # Log data
  log_data "$LOG_DIR" "$ERROR_LOG"

  # Format and send Telegram message
  format_telegram_message "$ip"
  send_telegram_message "$SUMMARY_MESSAGE" "$ERROR_LOG"

  # Attach log files based on configuration
  for attachment in \
    "$ATTACH_POWER_ANALYSIS_LOG:$LOG_DIR/power_analysis.log" \
    "$ATTACH_POWER_METRICS_CSV:$LOG_DIR/power_metrics.csv" \
    "$ATTACH_POWER_METRICS_JSONL:$LOG_DIR/power_metrics.jsonl" \
    "$ATTACH_FREQUENCY_VOLTAGE_TEMPS:$LOG_DIR/frequency_voltage_temps.csv"; do
    IFS=':' read -r flag log_file <<< "$attachment"
    flag=$(echo "$flag" | tr '[:lower:]' '[:upper:]')
    if [ "$flag" = "YES" ] && [ -f "$log_file" ]; then
      send_telegram_document "$log_file" "$ERROR_LOG"
    elif [ "$flag" != "NO" ]; then
      echo "[$TIMESTAMP] Warning: Invalid attachment flag ($flag) for $log_file. Use YES or NO." >>"$ERROR_LOG"
    fi
  done

  # Final log
  {
    echo "[$(date -u)] Data collected and sent to Telegram for Miner $i ($ip)."
    echo "------------------------"
  } >> "$LOG_DIR/power_analysis.log"
done

[ "$DEBUG" = true ] && echo "Script completed at $(date -u)"
