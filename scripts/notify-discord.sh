#!/usr/bin/env bash
# notify-discord.sh — Dynamic Discord webhook notifier
#
# REQUIRED:
#   DISCORD_WEBHOOK       Webhook URL
#   NOTIFICATION_TYPE     ci-success | ci-failure | activity | release | deploy | custom
#
# GITHUB CONTEXT (auto-detected from GITHUB_* env vars, override with GH_* prefix):
#   GH_ACTOR, GH_REPO, GH_BRANCH, GH_WORKFLOW, GH_RUN_NUMBER,
#   GH_RUN_ID, GH_SERVER_URL, GH_COMMIT_MSG, GH_EVENT
#
# TYPE-SPECIFIC:
#   release   → RELEASE_TAG, RELEASE_URL
#   deploy    → DEPLOY_ENV (default: production), DEPLOY_URL
#   custom    → EMBED_FIELDS_JSON (JSON array string)
#
# EMBED OVERRIDES (all optional):
#   EMBED_TITLE, EMBED_COLOR (decimal int), EMBED_DESCRIPTION
#   EXTRA_FIELDS_JSON  Extra fields appended to any type's fields
#   USERNAME           Bot display name
#   FOOTER_TEXT        Embed footer text

set -euo pipefail

# ── Required ─────────────────────────────────────────────────────────────────
if [[ -z "${DISCORD_WEBHOOK:-}" ]]; then
  echo "DISCORD_WEBHOOK not set — skipping notification"
  exit 0
fi
: "${NOTIFICATION_TYPE:?Missing NOTIFICATION_TYPE}"

# ── GitHub Actions context ────────────────────────────────────────────────────
ACTOR="${GH_ACTOR:-${GITHUB_ACTOR:-unknown}}"
REPO="${GH_REPO:-${GITHUB_REPOSITORY:-unknown/unknown}}"
BRANCH="${GH_BRANCH:-${GITHUB_REF_NAME:-main}}"
WORKFLOW_NAME="${GH_WORKFLOW:-${GITHUB_WORKFLOW:-CI}}"
RUN_NUMBER="${GH_RUN_NUMBER:-${GITHUB_RUN_NUMBER:-0}}"
RUN_ID="${GH_RUN_ID:-${GITHUB_RUN_ID:-0}}"
SERVER_URL="${GH_SERVER_URL:-${GITHUB_SERVER_URL:-https://github.com}}"
RUN_URL="${GH_RUN_URL:-${SERVER_URL}/${REPO}/actions/runs/${RUN_ID}}"
REPO_URL="${SERVER_URL}/${REPO}"
EVENT="${GH_EVENT:-${GITHUB_EVENT_NAME:-push}}"
COMMIT_MSG="${GH_COMMIT_MSG:-}"
AVATAR_URL="https://github.com/${ACTOR}.png"
ACTOR_URL="https://github.com/${ACTOR}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ── Defaults ──────────────────────────────────────────────────────────────────
USERNAME="${USERNAME:-Robtic CI}"
FOOTER_TEXT="${FOOTER_TEXT:-Robtic CI • Notification}"

# ── Build embed fields by type ────────────────────────────────────────────────
case "${NOTIFICATION_TYPE}" in

  ci-success)
    TITLE="${EMBED_TITLE:-🟢 CI Passed}"
    COLOR="${EMBED_COLOR:-5763719}"
    DESCRIPTION="${EMBED_DESCRIPTION:-}"
    FIELDS=$(jq -cn \
      --arg repo       "$REPO"       --arg repo_url  "$REPO_URL" \
      --arg branch     "$BRANCH"     --arg workflow  "$WORKFLOW_NAME" \
      --arg run        "#${RUN_NUMBER}" \
      --arg commit     "$COMMIT_MSG" --arg run_url   "$RUN_URL" \
      '[
        {"name":"📦 Repository","value":"[\($repo)](\($repo_url))","inline":true},
        {"name":"🌿 Branch","value":$branch,"inline":true},
        {"name":"⚙️ Workflow","value":$workflow,"inline":true},
        {"name":"🔢 Run Number","value":$run,"inline":true},
        (if $commit != "" then {"name":"📝 Commit / PR","value":$commit,"inline":false} else empty end),
        {"name":"🔗 Build Logs","value":"[Open GitHub Actions Run](\($run_url))","inline":false}
      ]')
    ;;

  ci-failure)
    TITLE="${EMBED_TITLE:-🔴 CI Failed}"
    COLOR="${EMBED_COLOR:-15548997}"
    DESCRIPTION="${EMBED_DESCRIPTION:-}"
    FIELDS=$(jq -cn \
      --arg repo       "$REPO"       --arg repo_url  "$REPO_URL" \
      --arg branch     "$BRANCH"     --arg workflow  "$WORKFLOW_NAME" \
      --arg run        "#${RUN_NUMBER}" \
      --arg commit     "$COMMIT_MSG" --arg run_url   "$RUN_URL" \
      '[
        {"name":"📦 Repository","value":"[\($repo)](\($repo_url))","inline":true},
        {"name":"🌿 Branch","value":$branch,"inline":true},
        {"name":"⚙️ Workflow","value":$workflow,"inline":true},
        {"name":"🔢 Run Number","value":$run,"inline":true},
        (if $commit != "" then {"name":"📝 Commit / PR","value":$commit,"inline":false} else empty end),
        {"name":"🔗 Build Logs","value":"[Open GitHub Actions Run](\($run_url))","inline":false}
      ]')
    ;;

  activity)
    USERNAME="${USERNAME:-Robtic GitHub}"
    TITLE="${EMBED_TITLE:-⭐ Repository Interaction}"
    COLOR="${EMBED_COLOR:-5814783}"
    DESCRIPTION="${EMBED_DESCRIPTION:-A new interaction occurred with the repository.}"
    case "$EVENT" in
      watch) EVENT_LABEL="⭐ Star" ;;
      fork)  EVENT_LABEL="🍴 Fork" ;;
      *)     EVENT_LABEL="$EVENT"  ;;
    esac
    FIELDS=$(jq -cn \
      --arg repo      "$REPO"      --arg repo_url  "$REPO_URL" \
      --arg event     "$EVENT_LABEL" \
      --arg actor     "$ACTOR"     --arg actor_url "$ACTOR_URL" \
      '[
        {"name":"📦 Repository","value":"[\($repo)](\($repo_url))","inline":true},
        {"name":"⚡ Event Type","value":$event,"inline":true},
        {"name":"👤 User","value":"[\($actor)](\($actor_url))","inline":true},
        {"name":"🔗 Open Repository","value":"[View Repository](\($repo_url))","inline":false}
      ]')
    ;;

  release)
    RELEASE_TAG="${RELEASE_TAG:-unknown}"
    RELEASE_URL="${RELEASE_URL:-${REPO_URL}/releases}"
    USERNAME="${USERNAME:-Robtic Releases}"
    TITLE="${EMBED_TITLE:-🚀 New Release: ${RELEASE_TAG}}"
    COLOR="${EMBED_COLOR:-3066993}"
    DESCRIPTION="${EMBED_DESCRIPTION:-A new release has been published.}"
    FIELDS=$(jq -cn \
      --arg repo      "$REPO"         --arg repo_url  "$REPO_URL" \
      --arg tag       "$RELEASE_TAG"  --arg rel_url   "$RELEASE_URL" \
      --arg actor     "$ACTOR"        --arg actor_url "$ACTOR_URL" \
      '[
        {"name":"📦 Repository","value":"[\($repo)](\($repo_url))","inline":true},
        {"name":"🏷️ Tag","value":$tag,"inline":true},
        {"name":"👤 Published by","value":"[\($actor)](\($actor_url))","inline":true},
        {"name":"🔗 View Release","value":"[Open Release](\($rel_url))","inline":false}
      ]')
    ;;

  deploy)
    DEPLOY_ENV="${DEPLOY_ENV:-production}"
    DEPLOY_URL="${DEPLOY_URL:-}"
    USERNAME="${USERNAME:-Robtic Deploys}"
    TITLE="${EMBED_TITLE:-🚢 Deployed to ${DEPLOY_ENV}}"
    COLOR="${EMBED_COLOR:-1752220}"
    DESCRIPTION="${EMBED_DESCRIPTION:-}"
    FIELDS=$(jq -cn \
      --arg repo       "$REPO"         --arg repo_url   "$REPO_URL" \
      --arg env        "$DEPLOY_ENV"   --arg branch      "$BRANCH" \
      --arg run_url    "$RUN_URL"      --arg deploy_url  "$DEPLOY_URL" \
      '[
        {"name":"📦 Repository","value":"[\($repo)](\($repo_url))","inline":true},
        {"name":"🌍 Environment","value":$env,"inline":true},
        {"name":"🌿 Branch","value":$branch,"inline":true},
        (if $deploy_url != "" then {"name":"🔗 Live URL","value":"[Open App](\($deploy_url))","inline":false} else empty end),
        {"name":"🔗 Deployment Run","value":"[View in GitHub Actions](\($run_url))","inline":false}
      ]')
    ;;

  custom)
    TITLE="${EMBED_TITLE:-📬 Notification}"
    COLOR="${EMBED_COLOR:-3447003}"
    DESCRIPTION="${EMBED_DESCRIPTION:-}"
    FIELDS="${EMBED_FIELDS_JSON:-[]}"
    ;;

  *)
    echo "❌ Unknown NOTIFICATION_TYPE: '${NOTIFICATION_TYPE}'" >&2
    echo "   Valid: ci-success | ci-failure | activity | release | deploy | custom" >&2
    exit 1
    ;;
esac

# Append extra custom fields if provided
if [[ -n "${EXTRA_FIELDS_JSON:-}" && "${EXTRA_FIELDS_JSON}" != "[]" ]]; then
  FIELDS=$(jq -cn --argjson base "${FIELDS}" --argjson extra "${EXTRA_FIELDS_JSON}" '$base + $extra')
fi

# ── Send payload ──────────────────────────────────────────────────────────────
PAYLOAD=$(jq -cn \
  --arg  username    "$USERNAME" \
  --arg  title       "$TITLE" \
  --arg  embed_url   "${RUN_URL:-$REPO_URL}" \
  --argjson color    "${COLOR}" \
  --arg  actor       "$ACTOR" \
  --arg  avatar      "$AVATAR_URL" \
  --arg  actor_url   "$ACTOR_URL" \
  --arg  description "${DESCRIPTION:-}" \
  --argjson fields   "${FIELDS}" \
  --arg  footer      "$FOOTER_TEXT" \
  --arg  timestamp   "$TIMESTAMP" \
  '{
    username: $username,
    embeds: [{
      title:       $title,
      url:         $embed_url,
      color:       $color,
      author: {name: $actor, icon_url: $avatar, url: $actor_url},
      description: (if $description != "" then $description else null end),
      fields:      $fields,
      footer:      {text: $footer},
      timestamp:   $timestamp
    }]
  }')

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  "$DISCORD_WEBHOOK")

if [[ "${HTTP_CODE}" -ge 200 && "${HTTP_CODE}" -lt 300 ]]; then
  echo "✅ Discord notification sent [${NOTIFICATION_TYPE}] (HTTP ${HTTP_CODE})"
else
  echo "❌ Discord webhook failed (HTTP ${HTTP_CODE})" >&2
  exit 1
fi
