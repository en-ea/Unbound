#!/usr/bin/env bash
# Downloads the first (free "Standard") file of a free itch.io asset pack.
# Usage: bash tools-src/itch_download.sh https://quaternius.itch.io/<pack> <out_dir>
G=$1; OUT=$2; J=$(mktemp); T=$(mktemp -d)
curl -s -c $J -b $J "$G" -o $T/g.html
c=$(grep -oE 'name="csrf_token" value="[^"]+"' $T/g.html | head -1 | sed 's/.*value="//;s/"//')
u=$(curl -s -c $J -b $J -X POST --data-urlencode "csrf_token=$c" "$G/download_url" | sed 's/.*"url":"//;s/".*//' | tr -d '\')
curl -s -c $J -b $J "$u" -o $T/d.html
grep -oE 'title="[^"]+\.(zip|rar|7z)"' $T/d.html
for id in $(grep -oE 'data-upload_id="[0-9]+"' $T/d.html | grep -oE '[0-9]+' | head -1); do
  r=$(curl -s -c $J -b $J -X POST --data-urlencode "csrf_token=$c" "$G/file/$id?source=view_game&as_props=1&after_download_lightbox=true")
  f=$(echo "$r" | grep -oE '"url":"https:[^"]*' | grep -E "cloudflarestorage|itchio-mirror" | tail -1 | sed 's/"url":"//' | tr -d '\')
  [ -n "$f" ] && curl -sL "$f" -o "$OUT/upload_$id.zip" && ls -la "$OUT/upload_$id.zip"
done
