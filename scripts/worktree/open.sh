#!/usr/bin/env bash
# Opens a worktree's app in the browser. When its .env sets WC_DEV_USERNAME, it signs in as that
# user with a short-lived sign-in token, made by the running server through Tidewave.
# Usage: open.sh <worktree-path>
set -euo pipefail

env_file="$1/.env"
url=$(sed -n 's/^WC_URL=//p' "$env_file")
port=$(sed -n 's/^WC_PORT=//p' "$env_file")
username=$(sed -n 's/^WC_DEV_USERNAME=//p' "$env_file")

if [[ -z $username ]]; then
  open "$url"
  exit
fi

code="
user = Ash.get!(WatchClub.Accounts.User, %{username: \"$username\"}, authorize?: false)

{:ok, token, _claims} =
  AshAuthentication.Jwt.token_for_user(user, %{\"purpose\" => \"sign_in\"},
    token_lifetime: {60, :seconds},
    purpose: :sign_in
  )

token"

# project_eval returns the inspected result: the token, or the error that was raised.
token=$(
  jq -n --arg code "$code" \
    '{jsonrpc: "2.0", id: 1, method: "tools/call", params: {name: "project_eval", arguments: {code: $code}}}' |
    curl -sSf "http://localhost:$port/tidewave/mcp" -d @- \
      -H 'content-type: application/json' -H 'accept: application/json, text/event-stream' |
    jq -r '.result.content[0].text | fromjson'
)

if [[ ! $token =~ ^[A-Za-z0-9_.-]+$ ]]; then
  echo "$token" >&2
  exit 1
fi

open "$url/auth/user/password/sign_in_with_token?token=$token"
