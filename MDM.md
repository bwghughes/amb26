# MDM owner — Codex API key for contest Macs

This page is for the IT / Jamf / Apple Business Manager person who owns the Macs.

You do not need to run the workshop. You only need to put one secret on each contest Mac.

## Purpose

These Macs run a short Xcode workshop. Pairs use **Codex** inside **Xcode Intelligence**. The workshop installer does **not** put the API key on the `curl` command. The key must already be on the Mac (MDM), or staff re-runs the same installer after your profile arrives.

Installer (staff or MDM; no key on this line). Safe to run as root — artifacts
land in `/Users/Ambassador`, not `$HOME` / `/var/root`. The contest user
`Ambassador` must already exist:

```bash
curl -fsSL https://raw.githubusercontent.com/bwghughes/amb26/main/scripts/install-workshop-agent.sh | bash
```

## Recommended payload: Environment Variables

Push a configuration profile with **Environment Variables**.

| Variable name | Value |
|---|---|
| `OPENAI_API_KEY` | the Codex / OpenAI API key (secret) |
| `CODEX_API_KEY` | same key, optional second name |

Put **at least one** of those names. Both is fine (same value).

This is the usual Jamf / Apple config-profile approach. After the user logs in, this should work:

```bash
launchctl getenv OPENAI_API_KEY
```

That is what GUI apps (Xcode opened from the Dock) can see. The installer also reads `CODEX_API_KEY` the same way.

## Alternative: managed preferences `com.openai.codex`

If you do not use Environment Variables, push a **custom settings / managed preferences** payload.

| Item | Value |
|---|---|
| Preference domain | **`com.openai.codex`** |
| Preferred key names | `OPENAI_API_KEY` or `CODEX_API_KEY` |
| Also accepted | `openai_api_key`, `codex_api_key`, `APIKey`, `api_key` |

`com.openai.codex` is the official Codex MDM domain.

The installer also reads the same key names from domain `com.apple.dt.Xcode` if they are there. Prefer `com.openai.codex` or Environment Variables, not Xcode defaults, for the secret.

## What the installer reads (first match wins)

The script never prints the key. It stops at the first non-empty value:

1. Process environment: `OPENAI_API_KEY`, then `CODEX_API_KEY`
2. `launchctl getenv`: `OPENAI_API_KEY`, then `CODEX_API_KEY`
3. `defaults read` on **`com.openai.codex`**, then `com.apple.dt.Xcode`, using the names in the table above
4. Any `.plist` under `/Library/Managed Preferences`, `/Library/Managed Preferences/Ambassador`, or `/Users/Ambassador/Library/Managed Preferences` that contains those key names

If it finds a key, it runs `codex login --with-api-key` **as user Ambassador** with:

`CODEX_HOME=/Users/Ambassador/Library/Developer/Xcode/CodingAssistant/codex`

That stores the login in **Ambassador’s** login Keychain, service **`Codex Auth`**. If `launchctl getenv` is still empty in that user’s GUI domain, the installer may call `launchctl setenv` there for `OPENAI_API_KEY` and `CODEX_API_KEY` so Dock-launched Xcode can see them.

Do **not** trust `$HOME` when this curl runs under MDM as root (`$HOME` is `/var/root`). Pack, Desktop Starter, LaunchAgent, agent.json, logs, and Codex all go under `/Users/Ambassador`. Files are `chown`’d to `Ambassador` (primary group from `id -gn Ambassador`). `launchctl bootstrap` targets `gui/$(id -u Ambassador)`, not the root domain. If `/Users/Ambassador` does not exist, the installer exits; creating that account is MDM’s job.

If MDM has not delivered a key yet, pack + workshop agent still finish. Codex login is skipped. Staff re-run the same `curl` after the profile is on the Mac.

## Scope

| Decision | Recommendation |
|---|---|
| Which Macs | Every contest / lab Mac that will run the workshop |
| User or device | Device-wide is best for a shared lab. Target the **Ambassador** account (home `/Users/Ambassador`). If user-scoped, that is the account that logs in for the session |
| Where the secret lives | A secure MDM payload only |
| Where it must **not** live | Git repos, `.env` files, `COMMANDS.md`, Slack, or the install URL |

## Order of operations

1. Push the MDM profile (Environment Variables, or `com.openai.codex`).
2. Confirm the profile is on the Mac **before** anyone uses Xcode Intelligence.
3. Staff (or MDM) run `curl -fsSL https://raw.githubusercontent.com/bwghughes/amb26/main/scripts/install-workshop-agent.sh | bash` (no key on that line). Running as root is OK; files land in `/Users/Ambassador` owned by that user.
4. If the profile arrives **late**, staff re-run that same `curl`. Do not add the key to the command.

## Verify (do not print the key)

Check that the value exists. Do **not** paste the output into email, chat, or a ticket.

```bash
# Environment Variables profile: should be non-empty
test -n "$(launchctl getenv OPENAI_API_KEY 2>/dev/null)" && echo "OPENAI_API_KEY is set" || echo "OPENAI_API_KEY is missing"
test -n "$(launchctl getenv CODEX_API_KEY 2>/dev/null)" && echo "CODEX_API_KEY is set" || echo "CODEX_API_KEY is missing"

# Alternative managed prefs (only if you used com.openai.codex)
defaults read com.openai.codex OPENAI_API_KEY >/dev/null 2>&1 && echo "com.openai.codex OPENAI_API_KEY is set" || echo "com.openai.codex OPENAI_API_KEY not found"
```

After a successful install (key was present):

```bash
# Keychain item created by: CODEX_HOME=.../CodingAssistant/codex  +  codex login --with-api-key
security find-generic-password -s "Codex Auth" >/dev/null 2>&1 && echo "Keychain Codex Auth is present" || echo "Keychain Codex Auth is missing"
```

Do not use `security find-generic-password -w`. That prints the secret.

## What not to do

- Do not put a key that starts with `sk-` in `COMMANDS.md`, `FACILITATOR.md`, this file, or any git repo.
- Do not pass the key on the `curl` line (`OPENAI_API_KEY=... curl ...` is not the supported setup).
- Do not commit a `.env` with the key.
- Do not put the key in the install URL.
- Do not email or Slack the raw key to room staff. Point them at the profile and this page.
