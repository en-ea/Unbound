#!/usr/bin/env bash
# Copies the latest web export (build/web) into web/, the folder Vercel serves. Run after exporting.
cd "$(dirname "$0")/.." && rm -rf web/*.html web/*.js web/*.wasm web/*.pck web/*.png web/*.webmanifest && cp build/web/* web/ && rm -f web/index.service.worker.js
echo "web/ updated: commit and push to publish"
