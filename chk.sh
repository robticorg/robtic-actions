set -uo pipefail
if [ -z "${DISCORD_WEBHOOK:-}" ]; then
  echo "DISCORD_WEBHOOK_DEPLOY not set — skipping notification"
  exit 0
fi

esc() {
  local s="$1"
  s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; s="${s//$'\n'/\\n}"; s="${s//$'\r'/}"
  printf '%s' "$s"
}

FIELDS="{\"name\":\"📦 Repository\",\"value\":\"$(esc "$REPO")\",\"inline\":true},{\"name\":\"🌿 Branch\",\"value\":\"$(esc "$BRANCH")\",\"inline\":true},{\"name\":\"🖥 Server\",\"value\":\"$(esc "$SERVER_LABEL")\",\"inline\":true}"

PAYLOAD="{\"username\":\"$(esc "$NOTIFY_USERNAME")\",\"embeds\":[{\"title\":\"$(esc "$TITLE")\",\"url\":\"$(esc "$RUN_URL")\",\"color\":$COLOR,\"description\":\"Deployment failed. Check the GitHub Actions logs.\",\"author\":{\"name\":\"$(esc "$ACTOR")\",\"icon_url\":\"$(esc "$AVATAR")\",\"url\":\"$(esc "$ACTOR_URL")\"},\"fields\":[$FIELDS],\"footer\":{\"text\":\"Robtic Deployment Pipeline\"},\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}]}"

curl -sf -H "Content-Type: application/json" -d "$PAYLOAD" "$DISCORD_WEBHOOK" >/dev/null \
  && echo "Discord notification sent [failure]" \
  || echo "Discord notification failed [failure]" >&2
