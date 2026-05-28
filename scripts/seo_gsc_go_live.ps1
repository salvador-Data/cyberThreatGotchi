# Interactive GSC + Bing Webmaster go-live for hackerplanet.dev
# DEPRECATED — use .\scripts\seo_all_engines_go_live.ps1 (covers all engines)
# This wrapper forwards for backward compatibility.

$Root = Split-Path $PSScriptRoot -Parent
& (Join-Path $Root "scripts\seo_all_engines_go_live.ps1") @args
