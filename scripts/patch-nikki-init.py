#!/usr/bin/env python3
"""Patch nikki.init and profile.js in the OpenWrt build tree for tmpfs Mixin & fast timeouts."""

from __future__ import annotations

import pathlib
import re
import shutil
import subprocess
import sys

NEW_GET_MIXIN_BLOCK = """\t# get profile
\tlocal profile_type; profile_type=$(echo "$profile" | cut -d ':' -f 1)
\tlocal profile_id; profile_id=$(echo "$profile" | cut -d ':' -f 2)
\tlocal tmp_profile="$TEMP_DIR/config.yaml"
\tif [ "$profile_type" = "file" ]; then
\t\tlocal profile_name; profile_name="$profile_id"
\t\tlocal profile_file; profile_file="$PROFILES_DIR/$profile_name"
\t\tlog "Profile" "Use file: $profile_name."
\t\tif [ ! -f "$profile_file" ]; then
\t\t\tlog "Profile" "File not found."
\t\t\tlog "App" "Exit."
\t\t\treturn
\t\tfi
\t\tcp -f "$profile_file" "$tmp_profile"
\telif [ "$profile_type" = "subscription" ]; then
\t\tlocal subscription_section; subscription_section="$profile_id"
\t\tlocal subscription_name subscription_prefer
\t\tconfig_get subscription_name "$subscription_section" "name"
\t\tconfig_get subscription_prefer "$subscription_section" "prefer" "remote"
\t\tlog "Profile" "Use subscription: $subscription_name."
\t\tlocal subscription_file; subscription_file="$SUBSCRIPTIONS_DIR/$subscription_section.yaml"
\t\tif [ "$subscription_prefer" = "remote" ] || [ ! -f "$subscription_file" ]; then
\t\t\tupdate_subscription "$subscription_section"
\t\tfi
\t\tif [ ! -f "$subscription_file" ]; then
\t\t\tlog "Profile" "Subscription file not found."
\t\t\tlog "App" "Exit."
\t\t\treturn
\t\tfi
\t\tcp -f "$subscription_file" "$tmp_profile"
\telse
\t\tlog "Profile" "No profile/subscription selected."
\t\tlog "App" "Exit."
\t\treturn
\tfi
\t# mixin (single-pass in tmpfs RAM to minimize CPU time and eMMC wear)
\tif [ "$core_only" = 0 ]; then
\t\tlog "Mixin" "Mixin config."
\t\tlocal del_expr="."
\t\tif [ "$overwrite_authentication" = 1 ]; then
\t\t\tdel_expr="$del_expr | del(.authentication)"
\t\tfi
\t\tif [ "$overwrite_tun_dns_hijack" = 1 ]; then
\t\t\tdel_expr="$del_expr | del(.tun.dns-hijack)"
\t\tfi
\t\tif [ "$overwrite_fake_ip_filter" = 1 ]; then
\t\t\tdel_expr="$del_expr | del(.dns.fake-ip-filter)"
\t\tfi
\t\tif [ "$overwrite_hosts" = 1 ]; then
\t\t\tdel_expr="$del_expr | del(.hosts)"
\t\tfi
\t\tif [ "$overwrite_dns_nameserver" = 1 ]; then
\t\t\tdel_expr="$del_expr | del(.dns.default-nameserver) | del(.dns.proxy-server-nameserver) | del(.dns.direct-nameserver) | del(.dns.nameserver) | del(.dns.fallback)"
\t\tfi
\t\tif [ "$overwrite_dns_nameserver_policy" = 1 ]; then
\t\t\tdel_expr="$del_expr | del(.dns.nameserver-policy)"
\t\tfi
\t\tif [ "$overwrite_sniffer_force_domain_name" = 1 ]; then
\t\t\tdel_expr="$del_expr | del(.sniffer.force-domain)"
\t\tfi
\t\tif [ "$overwrite_sniffer_ignore_domain_name" = 1 ]; then
\t\t\tdel_expr="$del_expr | del(.sniffer.skip-domain)"
\t\tfi
\t\tif [ "$overwrite_sniffer_sniff" = 1 ]; then
\t\t\tdel_expr="$del_expr | del(.sniffer.sniff)"
\t\tfi
\t\tif [ "$del_expr" != "." ]; then
\t\t\tyq -M -i "$del_expr" "$tmp_profile"
\t\tfi
\t\tlocal tun_expr=""
\t\tif [ "$proxy_enabled" = 1 ]; then
\t\t\ttun_expr=' | (select(has("tun")).tun) |= (.auto-route = false | .auto-redirect = false | .auto-detect-interface = false | .disable-icmp-forwarding = true) | (select(has("listeners")).listeners[] | select(.type == "tun")) |= (.auto-route = false | .auto-redirect = false | .auto-detect-interface = false | .disable-icmp-forwarding = true)'
\t\tfi
\t\tif [ "$mixin_file_content" = 0 ]; then
\t\t\tucode -S "$MIXIN_UC" | yq -M -p json -o yaml | yq -M -i eval-all "... comments=\\"\\" | . as \\$item ireduce ({}; . * \\$item ) | .proxies = .nikki-proxies + .proxies | del(.nikki-proxies) | .proxy-groups = .nikki-proxy-groups + .proxy-groups | del(.nikki-proxy-groups) | .rules = .nikki-rules + .rules | del(.nikki-rules) | explode(.)$tun_expr" "$tmp_profile" -
\t\telif [ "$mixin_file_content" = 1 ]; then
\t\t\tucode -S "$MIXIN_UC" | yq -M -p json -o yaml | yq -M -i eval-all "... comments=\\"\\" | . as \\$item ireduce ({}; . * \\$item ) | .proxies = .nikki-proxies + .proxies | del(.nikki-proxies) | .proxy-groups = .nikki-proxy-groups + .proxy-groups | del(.nikki-proxy-groups) | .rules = .nikki-rules + .rules | del(.nikki-rules) | explode(.)$tun_expr" "$tmp_profile" "$MIXIN_FILE_PATH" -
\t\tfi
\tfi
\tif ! cmp -s "$tmp_profile" "$RUN_PROFILE_PATH"; then
\t\tcp -f "$tmp_profile" "$RUN_PROFILE_PATH"
\tfi
\trm -f "$tmp_profile"
\t# check profile"""


def patch_nikki_init(path: pathlib.Path) -> None:
    original = path.read_text(encoding="utf-8")
    updated = original

    if "tmp_profile=\"$TEMP_DIR/config.yaml\"" not in updated:
        block_re = re.compile(r"\t# get profile\n[\s\S]*?\n\t# check profile")
        m = block_re.search(updated)
        required_tokens = (
            "overwrite_authentication",
            "overwrite_sniffer_sniff",
            "MIXIN_FILE_PATH",
            'has("listeners")',
        )
        if m and all(tok in m.group(0) for tok in required_tokens):
            updated = updated[: m.start()] + NEW_GET_MIXIN_BLOCK + updated[m.end() :]
            print(f"[patch-nikki-init] Patched tmpfs single-pass Mixin in {path}")
        else:
            print(f"[patch-nikki-init] WARNING: Mixin block layout changed in {path}; skipping Mixin patch")

    old_curl = "-m 120 --connect-timeout 15 --retry 3"
    new_curl = "-m 30 --connect-timeout 10 --retry 1"
    if old_curl in updated:
        updated = updated.replace(old_curl, new_curl)
        print(f"[patch-nikki-init] Updated curl timeouts in {path}")

    if updated != original:
        path.write_text(updated, encoding="utf-8", newline="\n")
        sh_bin = shutil.which("sh")
        if sh_bin:
            res = subprocess.run([sh_bin, "-n", str(path)], capture_output=True, text=True)
            if res.returncode != 0:
                path.write_text(original, encoding="utf-8", newline="\n")
                print(
                    f"[patch-nikki-init] WARNING: sh -n failed on {path}; restored original:\n{res.stderr}"
                )
            else:
                print(f"[patch-nikki-init] Verified shell syntax (sh -n) for {path}")


def patch_profile_js(path: pathlib.Path) -> None:
    original = path.read_text(encoding="utf-8")
    pattern = re.compile(
        r"(option\(form\.ListValue,\s*['\"]prefer['\"](?:(?!\.option\()[\s\S]){0,250}?\.default\s*=\s*)(['\"])remote\2"
    )
    updated, count = pattern.subn(r"\1\2local\2", original, count=1)
    if count:
        path.write_text(updated, encoding="utf-8", newline="\n")
        print(f"[patch-nikki-init] Set default prefer='local' in {path}")
    elif "'prefer'" in original and "'local'" in original:
        print(f"[patch-nikki-init] profile.js already defaults or does not match 'remote' in {path}")


def main() -> int:
    if len(sys.argv) > 1:
        targets = [pathlib.Path(p) for p in sys.argv[1:]]
        for t in targets:
            if not t.exists():
                print(f"[patch-nikki-init] WARNING: Missing target {t}")
                continue
            if t.name.endswith(".js"):
                patch_profile_js(t)
            else:
                patch_nikki_init(t)
        return 0

    root = pathlib.Path(".")
    init_candidates = list(root.glob("feeds/nikki/**/nikki.init")) + list(
        root.glob("package/**/nikki.init")
    )
    js_candidates = list(
        root.glob("feeds/nikki/**/view/nikki/profile.js")
    ) + list(root.glob("package/**/view/nikki/profile.js"))

    if not init_candidates:
        print("[patch-nikki-init] WARNING: nikki.init not found under feeds/nikki or package/")
    for p in dict.fromkeys(init_candidates):
        patch_nikki_init(p)
    for p in dict.fromkeys(js_candidates):
        patch_profile_js(p)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
