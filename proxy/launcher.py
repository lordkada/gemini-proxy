"""Start gemini-web2api configured from environment variables and the live session file.

Upstream reads its XSRF token, build label and account index from a config file
once at startup. Those values rotate, so a watcher thread copies them from
/session/session.json (written by session-sync) into the live CONFIG dict,
which upstream reads on every request. Cookies come from the same file through
upstream's own cookie_file loader, which reloads on change.
"""
import json
import os
import sys
import threading
import time

from gemini_web2api.config import CONFIG
from gemini_web2api import __main__ as web2api
from gemini_web2api import server

SESSION_FILE = "/session/session.json"
SESSION_KEYS = ("xsrf_token", "gemini_bl", "auth_user")

# Upstream puts the tool-use instructions at the top of the prompt. Agent harnesses
# such as opencode follow with a very long system prompt, and the model then often
# *describes* its next step ("Let's read calc.py") instead of emitting the call,
# which ends the agent's turn, or tries Gemini's own code-execution sandbox, which cannot
# see the user's files. Repeating the rules at the end of the prompt fixes most of it.
TOOL_REMINDER = {
    "openai": "tool_call",
    "google": "function_call",
}
TOOL_REMINDER_TEXT = (
    "\n\n---\nREMINDER: you are an agent connected to the user's machine through the tools above. "
    "If the next step needs reading, searching, editing or writing files, or running a command, "
    "do not describe it and do not ask for permission: output the ```{block} block(s) now, "
    "in the exact format given above. Do not use your own built-in code execution or Python "
    "sandbox: it cannot see the user's files, only the tools above can. Answer with plain text "
    "only when the task is complete or you need information from the user."
)


def install_tool_reminder():
    openai_builder = server.messages_to_prompt
    google_builder = server.google_contents_to_prompt

    def messages_to_prompt(messages, tools=None, tool_choice=None):
        prompt, images = openai_builder(messages, tools, tool_choice)
        if tools and tool_choice != "none":
            prompt += TOOL_REMINDER_TEXT.format(block=TOOL_REMINDER["openai"])
        return prompt, images

    def google_contents_to_prompt(req):
        prompt, images = google_builder(req)
        mode = req.get("toolConfig", {}).get("functionCallingConfig", {}).get("mode", "AUTO")
        if req.get("tools") and mode != "NONE":
            prompt += TOOL_REMINDER_TEXT.format(block=TOOL_REMINDER["google"])
        return prompt, images

    server.messages_to_prompt = messages_to_prompt
    server.google_contents_to_prompt = google_contents_to_prompt


def watch_session():
    last_mtime = None
    warned = False
    while True:
        try:
            mtime = os.path.getmtime(SESSION_FILE)
            if mtime != last_mtime:
                with open(SESSION_FILE) as f:
                    data = json.load(f)
                for key in SESSION_KEYS:
                    CONFIG[key] = data.get(key)
                last_mtime = mtime
                print(f"session loaded (build: {CONFIG['gemini_bl']})", flush=True)
        except FileNotFoundError:
            if not warned:
                print("waiting for session file: sign in through the browser UI", flush=True)
                warned = True
        except (OSError, ValueError) as e:
            print(f"session file not readable yet: {e}", flush=True)
        time.sleep(5)


def main():
    api_key = os.environ.get("PROXY_API_KEY", "").strip()
    if not api_key:
        sys.exit("PROXY_API_KEY is not set")

    CONFIG.update({
        "host": "0.0.0.0",
        "port": 8081,
        "api_keys": [api_key],
        "cookie_file": SESSION_FILE,
        "default_model": os.environ.get("DEFAULT_MODEL", "gemini-3.6-flash"),
        "temporary_chats": os.environ.get("TEMPORARY_CHATS", "true").lower() == "true",
        "retry_attempts": 2,
        "request_timeout_sec": 180,
    })
    if os.environ.get("TOOL_REMINDER", "true").lower() == "true":
        install_tool_reminder()
    threading.Thread(target=watch_session, daemon=True).start()

    # No --config argument and no config.json in /app: upstream keeps the CONFIG set above.
    sys.argv = [sys.argv[0]]
    web2api.main()


if __name__ == "__main__":
    main()
