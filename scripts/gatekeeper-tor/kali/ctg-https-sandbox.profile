# CTG Gatekeeper HTTPS sandbox — Firejail profile (authorized Kali lab only)
# Hacker Planet LLC · CyberThreatGotchi
# Install: /etc/firejail/ctg-https-sandbox.profile
#
# HTTPS ≠ sandbox. This profile contains the *browser process* when HTTPS mode is lit.
# TLS still required for sensitive sites; HTTP is lab captive/legacy only (site-rules allowlist).

include disable-common.inc
include disable-programs.inc
include disable-middleware.inc
include firefox-common.profile

env CTG_SANDBOX=1
env MOZ_DISABLE_CONTENT_SANDBOX=0

# Containment
noroot
seccomp
caps.drop all
nonewprivs
private-dev
private-tmp
netfilter

# No persistent home writes — ephemeral home + lab scratch only
private-home
mkdir /tmp/ctg-sandbox
whitelist /tmp/ctg-sandbox

# Fresh ephemeral Firefox profile under lab scratch
whitelist /usr/lib/firefox-esr
whitelist /usr/lib/firefox
whitelist /usr/bin/firefox-esr
whitelist /usr/bin/firefox
