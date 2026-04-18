#!/usr/bin/env bash
# conversation provider — artifact.sh
# URIs: conversation:<slug>  → $XDG_STATE_HOME/workflow/conversations/<slug>.jsonl
set -euo pipefail

die() { printf '{"error":"%s"}\n' "$*"; exit 2; }
need() { command -v "$1" >/dev/null 2>&1 || die "$1 not found"; }
need jq

: "${XDG_STATE_HOME:=$HOME/.local/state}"
base="$XDG_STATE_HOME/workflow/conversations"
mkdir -p "$base"

path_for() { echo "$base/$1.jsonl"; }
slug_from_uri() {
  local u="$1"; local s="${u#conversation:}"
  [ "$s" = "$u" ] && die "bad uri: $u"
  printf '%s' "$s"
}

cmd="${1:?subcommand required}"; shift || true

case "$cmd" in
  get)
    uri=""; while [ $# -gt 0 ]; do case "$1" in --uri) uri="$2"; shift 2;; *) shift;; esac; done
    f=$(path_for "$(slug_from_uri "$uri")")
    [ -f "$f" ] || { jq -n --arg uri "$uri" '{uri:$uri, exists:false}'; exit 0; }
    jq -s --arg uri "$uri" '{uri:$uri, exists:true, turns:.}' "$f"
    ;;
  create)
    data_path=""; while [ $# -gt 0 ]; do case "$1" in --data) data_path="$2"; shift 2;; *) shift;; esac; done
    data=$( [ "$data_path" = "-" ] && cat || cat "$data_path" )
    slug=$(jq -r '.slug' <<< "$data")
    [ -n "$slug" ] || die "data.slug required"
    f=$(path_for "$slug")
    [ ! -f "$f" ] || die "already-exists"
    jq -c '.metadata // {}' <<< "$data" > "$f"
    jq -n --arg uri "conversation:$slug" '{uri:$uri, created:true}'
    ;;
  update)
    uri=""; patch_path=""
    while [ $# -gt 0 ]; do case "$1" in
      --uri) uri="$2"; shift 2;;
      --patch) patch_path="$2"; shift 2;;
      *) shift;; esac; done
    f=$(path_for "$(slug_from_uri "$uri")")
    patch=$( [ "$patch_path" = "-" ] && cat || cat "$patch_path" )
    # Either append a turn or update header metadata.
    turn=$(jq -c '.turn // empty' <<< "$patch")
    if [ -n "$turn" ] && [ "$turn" != "null" ]; then
      printf '%s\n' "$turn" >> "$f"
    fi
    jq -n --arg uri "$uri" '{uri:$uri, updated:true}'
    ;;
  list)
    entries="[]"
    for f in "$base"/*.jsonl; do
      [ -f "$f" ] || continue
      slug=$(basename "$f" .jsonl)
      entries=$(jq --arg uri "conversation:$slug" '. + [{uri:$uri}]' <<< "$entries")
    done
    jq --argjson es "$entries" '{entries:$es}' <<< '{}'
    ;;
  lock|release)
    jq -n '{held:true, current_owner:"local"}'
    ;;
  status)
    uri=""; while [ $# -gt 0 ]; do case "$1" in --uri) uri="$2"; shift 2;; *) shift;; esac; done
    f=$(path_for "$(slug_from_uri "$uri")")
    if [ -f "$f" ]; then jq -n --arg uri "$uri" '{uri:$uri, status:"running"}'
    else jq -n --arg uri "$uri" '{uri:$uri, status:"unknown"}'; fi
    ;;
  progress)
    uri=""; append_path=""
    while [ $# -gt 0 ]; do case "$1" in
      --uri) uri="$2"; shift 2;;
      --append) append_path="$2"; shift 2;;
      *) shift;; esac; done
    f=$(path_for "$(slug_from_uri "$uri")")
    if [ -z "$append_path" ]; then
      [ -f "$f" ] || { jq -n '{entries:[]}'; exit 0; }
      # Skip first line (metadata) and treat rest as turns+progress
      tail -n +2 "$f" 2>/dev/null | jq -s '{entries:.}' || jq -n '{entries:[]}'
    else
      entry=$( [ "$append_path" = "-" ] && cat || cat "$append_path" )
      printf '%s\n' "$(jq -c . <<< "$entry")" >> "$f"
      jq -n '{appended:true}'
    fi
    ;;
  *)
    die "unknown subcommand: $cmd"
    ;;
esac
