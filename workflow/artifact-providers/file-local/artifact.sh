#!/usr/bin/env bash
# file-local provider — artifact.sh
#
# URIs: file-local:<relative-path>   (relative to git worktree root)
# Subcommands: get | create | update | list | lock | release | status | progress
set -euo pipefail

die() { printf '{"error":"%s"}\n' "$*"; exit 2; }
need() { command -v "$1" >/dev/null 2>&1 || die "$1 not found on PATH"; }

need jq

root() { git rev-parse --show-toplevel 2>/dev/null || pwd; }

parse_uri() {
  local u="$1"
  local rel="${u#file-local:}"
  case "$rel" in
    /*|*..*) die "rejected path: $rel" ;;
    "$u")    die "bad uri: $u" ;;
  esac
  printf '%s/%s\n' "$(root)" "$rel"
  printf '%s\n' "$rel"
}

cmd="${1:?subcommand required}"; shift || true

case "$cmd" in
  get)
    uri=""; while [ $# -gt 0 ]; do case "$1" in --uri) uri="$2"; shift 2;; *) shift;; esac; done
    { read -r abs; read -r rel; } < <(parse_uri "$uri")
    if [ ! -f "$abs" ]; then jq -n --arg uri "$uri" '{uri:$uri, exists:false}'; exit 0; fi
    content=$(cat "$abs")
    jq -n --arg uri "$uri" --arg c "$content" '{uri:$uri, exists:true, content:$c}'
    ;;

  create)
    data_path=""
    while [ $# -gt 0 ]; do case "$1" in --data) data_path="$2"; shift 2;; *) shift;; esac; done
    data=$( [ "$data_path" = "-" ] && cat || cat "$data_path" )
    rel=$(jq -r '.path // empty' <<< "$data")
    content=$(jq -r '.content // ""' <<< "$data")
    [ -n "$rel" ] || die "data.path required"
    abs="$(root)/$rel"
    mkdir -p "$(dirname "$abs")"
    printf '%s' "$content" > "$abs"
    jq -n --arg uri "file-local:$rel" '{uri:$uri, created:true}'
    ;;

  update)
    uri=""; patch_path=""
    while [ $# -gt 0 ]; do case "$1" in
      --uri) uri="$2"; shift 2;;
      --patch) patch_path="$2"; shift 2;;
      *) shift;; esac; done
    { read -r abs; read -r rel; } < <(parse_uri "$uri")
    patch=$( [ "$patch_path" = "-" ] && cat || cat "$patch_path" )
    # Default semantics: replace content with patch.content; if patch has
    # only partial fields, the caller passes content directly.
    new=$(jq -r '.content // empty' <<< "$patch")
    if [ -z "$new" ]; then die "patch.content required for file-local"; fi
    mkdir -p "$(dirname "$abs")"
    printf '%s' "$new" > "$abs"
    jq -n --arg uri "$uri" '{uri:$uri, updated:true}'
    ;;

  list)
    filter_path="" ; while [ $# -gt 0 ]; do case "$1" in --filter) filter_path="$2"; shift 2;; *) shift;; esac; done
    filter=$( [ -z "$filter_path" ] && echo '{}' || ( [ "$filter_path" = "-" ] && cat || cat "$filter_path" ))
    glob=$(jq -r '.glob // "**/*"' <<< "$filter")
    r="$(root)"
    entries="[]"
    while IFS= read -r -d '' f; do
      rel="${f#$r/}"
      entries=$(jq --arg uri "file-local:$rel" '. + [{uri:$uri}]' <<< "$entries")
    done < <(find "$r" -type f -path "$r/$glob" -print0 2>/dev/null || true)
    jq --argjson es "$entries" '{entries:$es}' <<< '{}'
    ;;

  lock)
    uri=""; owner=""; check=0
    while [ $# -gt 0 ]; do case "$1" in
      --uri) uri="$2"; shift 2;;
      --owner) owner="$2"; shift 2;;
      --check) check=1; shift;;
      *) shift;; esac; done
    { read -r abs; read -r rel; } < <(parse_uri "$uri")
    lock_file="$abs.lock"
    if [ "$check" = "1" ]; then
      if [ -f "$lock_file" ]; then
        held_by=$(cat "$lock_file" 2>/dev/null || echo "")
        if [ "$held_by" = "$owner" ]; then
          jq -n --arg o "$owner" '{held:true, current_owner:$o}'
        else
          jq -n --arg c "$held_by" '{held:false, current_owner:$c}'
        fi
      else
        jq -n '{held:false, current_owner:""}'
      fi
    else
      mkdir -p "$(dirname "$lock_file")"
      if [ -f "$lock_file" ]; then
        existing=$(cat "$lock_file" 2>/dev/null || echo "")
        if [ -n "$existing" ] && [ "$existing" != "$owner" ]; then
          jq -n --arg c "$existing" '{held:false, error:"lock-mismatch", current_owner:$c}'
          exit 4
        fi
      fi
      printf '%s' "$owner" > "$lock_file"
      jq -n --arg o "$owner" '{held:true, current_owner:$o}'
    fi
    ;;

  release)
    uri=""; owner=""
    while [ $# -gt 0 ]; do case "$1" in
      --uri) uri="$2"; shift 2;;
      --owner) owner="$2"; shift 2;;
      *) shift;; esac; done
    { read -r abs; read -r rel; } < <(parse_uri "$uri")
    lock_file="$abs.lock"
    if [ -f "$lock_file" ]; then
      existing=$(cat "$lock_file" 2>/dev/null || echo "")
      if [ -z "$existing" ] || [ "$existing" = "$owner" ]; then
        rm -f "$lock_file"
      fi
    fi
    jq -n '{released:true}'
    ;;

  status)
    uri=""; while [ $# -gt 0 ]; do case "$1" in --uri) uri="$2"; shift 2;; *) shift;; esac; done
    { read -r abs; read -r rel; } < <(parse_uri "$uri")
    if [ -f "$abs" ]; then
      jq -n --arg uri "$uri" '{uri:$uri, status:"complete"}'
    else
      jq -n --arg uri "$uri" '{uri:$uri, status:"unknown"}'
    fi
    ;;

  progress)
    uri=""; append_path=""
    while [ $# -gt 0 ]; do case "$1" in
      --uri) uri="$2"; shift 2;;
      --append) append_path="$2"; shift 2;;
      *) shift;; esac; done
    { read -r abs; read -r rel; } < <(parse_uri "$uri")
    log="$abs.progress.jsonl"
    if [ -z "$append_path" ]; then
      entries="[]"
      if [ -f "$log" ]; then
        entries=$(jq -s '.' "$log" 2>/dev/null || echo '[]')
      fi
      jq --argjson es "$entries" '{entries:$es}' <<< '{}'
    else
      entry=$( [ "$append_path" = "-" ] && cat || cat "$append_path" )
      mkdir -p "$(dirname "$log")"
      printf '%s\n' "$(jq -c . <<< "$entry")" >> "$log"
      jq -n '{appended:true}'
    fi
    ;;

  *)
    die "unknown subcommand: $cmd"
    ;;
esac
