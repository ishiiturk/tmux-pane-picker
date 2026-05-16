#!/usr/bin/env bash
set -euo pipefail

APP_NAME="TmuxPanePicker"
INSTALL_APP="$HOME/Applications/$APP_NAME.app"
LAUNCH_AGENT_ID="dev.taikiishii.tmux-pane-picker"
LAUNCH_AGENT_PLIST="$HOME/Library/LaunchAgents/$LAUNCH_AGENT_ID.plist"
GUI_DOMAIN="gui/$(id -u)"

if launchctl print "$GUI_DOMAIN/$LAUNCH_AGENT_ID" >/dev/null 2>&1; then
  launchctl bootout "$GUI_DOMAIN" "$LAUNCH_AGENT_PLIST" >/dev/null 2>&1 || true
fi

if pgrep -f "/tmux-pane-picker$" >/dev/null 2>&1; then
  pkill -f "/tmux-pane-picker$"
fi

rm -f "$LAUNCH_AGENT_PLIST"
rm -rf "$INSTALL_APP"

echo "Uninstalled $APP_NAME"
