"""Keep the proxy's view of the Gemini web session fresh.

Every SYNC_INTERVAL_SEC seconds this opens Gemini in a background tab of the
shared Chromium, reads the page tokens the web app needs (XSRF token and
frontend build label), collects the Google cookies, and atomically writes
everything to /session/session.json. The proxy re-reads that file whenever it
changes, so no restart is needed when tokens rotate.
"""
import json
import os
import re
import time

from playwright.sync_api import sync_playwright

CDP_URL = "http://127.0.0.1:9222"
OUT = "/session/session.json"
INTERVAL = int(os.environ.get("SYNC_INTERVAL_SEC", "600"))
RETRY_INTERVAL = 10
AUTH_USER = os.environ.get("GEMINI_AUTH_USER", "").strip()
REQUIRED_COOKIES = {"__Secure-1PSID", "SAPISID"}

PAGE_TOKENS_JS = """() => {
  const w = window.WIZ_global_data || {};
  return {xsrf_token: w.SNlM0e || null, gemini_bl: w.cfb2h || null};
}"""


def gemini_url():
    prefix = f"/u/{AUTH_USER}" if AUTH_USER else ""
    return f"https://gemini.google.com{prefix}/app"


def read_session(ctx):
    """Return the session dict, or None (with a reason) if not signed in."""
    page = ctx.new_page()
    try:
        page.goto(gemini_url(), wait_until="domcontentloaded", timeout=60_000)
        tokens = page.evaluate(PAGE_TOKENS_JS)
        url = page.url
    finally:
        page.close()

    if "accounts.google.com" in url or not tokens.get("xsrf_token"):
        return None, "not signed in to Gemini (open the browser UI and log in)"

    jar = {c["name"]: c["value"] for c in ctx.cookies(["https://gemini.google.com"])}
    missing = REQUIRED_COOKIES - jar.keys()
    if missing:
        return None, f"missing cookies {sorted(missing)}"

    m = re.search(r"gemini\.google\.com/u/(\d+)/", url)
    return {
        # "cookie" and "sapisid" are the keys the proxy's cookie loader expects.
        "cookie": "; ".join(f"{k}={v}" for k, v in jar.items()),
        "sapisid": jar["SAPISID"],
        "xsrf_token": tokens["xsrf_token"],
        "gemini_bl": tokens["gemini_bl"],
        "auth_user": m.group(1) if m else (AUTH_USER or None),
        "updated_at": int(time.time()),
    }, None


def write_session(data):
    tmp = OUT + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f)
    os.chmod(tmp, 0o644)
    os.replace(tmp, OUT)


def sync_once():
    with sync_playwright() as p:
        browser = p.chromium.connect_over_cdp(CDP_URL)
        data, reason = read_session(browser.contexts[0])
    if data is None:
        print(f"waiting: {reason}")
        return False
    write_session(data)
    print(f"session exported (account index: {data['auth_user'] or 'default'}, build: {data['gemini_bl']})")
    return True


def main():
    print(f"session-sync started, refresh every {INTERVAL}s")
    while True:
        try:
            ok = sync_once()
        except Exception as e:  # browser still starting, page timeout, ...
            print(f"sync failed: {e}")
            ok = False
        time.sleep(INTERVAL if ok else RETRY_INTERVAL)


if __name__ == "__main__":
    main()
