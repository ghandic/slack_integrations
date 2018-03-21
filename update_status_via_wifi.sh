#!/bin/bash
SLACKAPIKEY=`osascript -e 'set T to text returned of (display dialog "Enter your Slack OAuth API key" buttons {"Cancel", "OK"} default button "OK" default answer "" with hidden answer)'`

# Setting times to sleep in the script
ENDHOUR=`osascript -e 'set T to text returned of (display dialog "What hour do you leave work?" buttons {"Cancel", "OK"} default button "OK" default answer 17)'`
STARTHOUR=`osascript -e 'set T to text returned of (display dialog "What hour do you get to work?" buttons {"Cancel", "OK"} default button "OK" default answer 8)'`

# Setting the work wifi ssid
MYWORKSSID=`osascript -e 'set T to text returned of (display dialog "What is the SSID (name) of you office Wifi?" buttons {"Cancel", "OK"} default button "OK" default answer "MyOfficeWiFi")'`

# Setting the country code
COUNTRYCODE=`osascript -e 'set T to text returned of (display dialog "What is your country code?" buttons {"Cancel", "OK"} default button "OK" default answer "ENG")'`


# Detemine if api key is valid
IS_VALID=`curl https://slack.com/api/auth.test --data 'token='$SLACKAPIKEY |     python -c "import sys, json; print json.load(sys.stdin)['ok']"`

if [ $IS_VALID == "True" ]; then
	slackstatus_shell_path="/Users/"$USER"/Library/LaunchAgents/slackstatus.sh"
	slackstatus_plist_path="/Users/"$USER"/Library/LaunchAgents/local.slackstatus.plist"
	slackstatus_location_python_path="/Users/"$USER"/Library/LaunchAgents/get_location.py"

	cat <<< 'import requests
import json

send_url = "http://freegeoip.net/json"
r = requests.get(send_url)
j = json.loads(r.text)
county_code = j["region_code"]
print(county_code)' > $slackstatus_location_python_path

	cat <<< "#!/bin/bash
while [ \`date +%H\` -gt $ENDHOUR ] && [ \`date +%H\` -lt $STARTHOUR ]
do
sleep 1h
done

ssid=\`/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | awk '/ SSID/ {print substr(\$0, index(\$0, \$2))}'\`
slack_token=\""$SLACKAPIKEY"\"

# Check my location from the ip address
location=\`python "$slackstatus_location_python_path"\`

if [ \"\$ssid\" == \"$MYWORKSSID\" ]; then
    # set status to 'In the office'
    /usr/bin/curl https://slack.com/api/users.profile.set --data 'token='\$slack_token'&profile=%7B%22status_text%22%3A%20%22In%20the%20office%22%2C%22status_emoji%22%3A%20%22%3Aoffice%3A%22%7D' > /dev/null
elif [ \"\$location\" != \"$COUNTRYCODE\" || \"\$location\" != \"\" ]; then
	# set status to 'On holiday'
    /usr/bin/curl https://slack.com/api/users.profile.set --data 'token='\$slack_token'&profile=%7B%22status_text%22%3A%20%22On%20holiday%22%2C%22status_emoji%22%3A%20%22%3Aairplane_departure%3A%22%7D' > /dev/null
else
    # set status to 'Working remotely'
    /usr/bin/curl https://slack.com/api/users.profile.set --data 'token='\$slack_token'&profile=%7B%22status_text%22%3A%20%22Working%20remotely%22%2C%22status_emoji%22%3A%20%22%3Ahouse_with_garden%3A%22%7D' > /dev/null
fi" > $slackstatus_shell_path
	chmod a+x $slackstatus_shell_path

	cat <<< '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN"  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>local.slackstatus</string>

  <key>ProgramArguments</key>
  <array>
  <string>'$slackstatus_shell_path'</string>
  </array>

  <key>WatchPaths</key>
  <array>
    <string>/etc/resolv.conf</string>
    <string>/Library/Preferences/SystemConfiguration/NetworkInterfaces.plist</string>
    <string>/Library/Preferences/SystemConfiguration/com.apple.airport.preferences.plist</string>
  </array>

  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>' > $slackstatus_plist_path


	launchctl unload -w $slackstatus_plist_path
	launchctl load -w $slackstatus_plist_path
else
	osascript -e 'display dialog "We could not verify that token" buttons {"Cancel", "OK"} default button "OK"'
fi



