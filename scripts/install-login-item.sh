#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="TmuxPanePicker"
APP_BUNDLE="$APP_NAME.app"
INSTALL_DIR="$HOME/Applications"
INSTALL_APP="$INSTALL_DIR/$APP_BUNDLE"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
LAUNCH_AGENT_ID="dev.taikiishii.tmux-pane-picker"
LAUNCH_AGENT_PLIST="$LAUNCH_AGENTS_DIR/$LAUNCH_AGENT_ID.plist"
GUI_DOMAIN="gui/$(id -u)"

cd "$ROOT_DIR"

"$ROOT_DIR/scripts/build-app.sh" >/dev/null

mkdir -p "$INSTALL_DIR" "$LAUNCH_AGENTS_DIR"

if pgrep -f "/tmux-pane-picker$" >/dev/null 2>&1; then
  pkill -f "/tmux-pane-picker$"
fi

rm -rf "$INSTALL_APP"
cp -R "$ROOT_DIR/dist/$APP_BUNDLE" "$INSTALL_APP"

cat > "$LAUNCH_AGENT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$LAUNCH_AGENT_ID</string>
	<key>ProgramArguments</key>
	<array>
		<string>/usr/bin/open</string>
		<string>$INSTALL_APP</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
</dict>
</plist>
PLIST

if launchctl print "$GUI_DOMAIN/$LAUNCH_AGENT_ID" >/dev/null 2>&1; then
  launchctl bootout "$GUI_DOMAIN" "$LAUNCH_AGENT_PLIST" >/dev/null 2>&1 || true
fi

launchctl bootstrap "$GUI_DOMAIN" "$LAUNCH_AGENT_PLIST"
launchctl kickstart -k "$GUI_DOMAIN/$LAUNCH_AGENT_ID"

echo "Installed $INSTALL_APP"
echo "Registered $LAUNCH_AGENT_PLIST"
