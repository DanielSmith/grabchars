# forms/

Spawn scripts for using grabchars from coding agents and shell scripts
that lack a TTY.

These are wrappers around the pattern documented in `docs/INTERACTIVE-FORMS.md`:
open a new terminal window, run grabchars there, write the result to a temp
file, return JSON to the caller.

## Scripts

| Script | Purpose |
|--------|---------|
| `spawn-decision.sh` | y/n confirmation with timeout and safe default |
| `spawn-select.sh` | Choose from a list using grabchars select/select-lr |
| `spawn-intake.sh` | Multi-field form driven by a JSON field-spec file |

---

## Testing standalone

Run any script directly from a terminal. Each prints JSON to stdout.

### spawn-decision.sh

```bash
# Basic — default n, 30s timeout
./forms/spawn-decision.sh "Deploy to production?"

# Custom default and timeout
./forms/spawn-decision.sh "Overwrite 12 files?" n 10

# Default yes — press Enter or wait
./forms/spawn-decision.sh "Looks good?" y 20
```

Expected output (user pressed y):
```json
{"status":"y","timed_out":false}
```

Expected output (timer expired, default was n):
```json
{"status":"n","timed_out":true}
```

Expected output (user pressed Escape):
```json
{"status":"cancelled"}
```

---

### spawn-select.sh

```bash
# Vertical filter-as-you-type (default layout)
./forms/spawn-select.sh "dev,staging,prod" "Deploy to:"

# Horizontal left/right, with default and timeout
./forms/spawn-select.sh "accept,reject,skip" "Code review:" h accept 30

# Longer list — vertical works better
./forms/spawn-select.sh "main,feature/auth,feature/payments,fix/login,fix/typo" "Branch:"
```

Expected output:
```json
{"status":"selected","value":"staging"}
```

---

### spawn-intake.sh

Requires a JSON field-spec file. A sample is provided:

```bash
# Create a sample fields file
cat > /tmp/test-fields.json << 'EOF'
[
  { "name": "app_name",    "type": "text",      "prompt": "App name: ",      "maxlen": 30 },
  { "name": "port",        "type": "masked",     "prompt": "Port: ",          "mask": "nnnn", "default": "8080" },
  { "name": "environment", "type": "select",     "prompt": "Environment: ",   "choices": "dev,staging,prod" },
  { "name": "confirmed",   "type": "yn",         "prompt": "Looks good? ",    "default": "y", "timeout": 15 }
]
EOF

./forms/spawn-intake.sh /tmp/test-fields.json "New App Setup"
```

Expected output:
```json
{
  "status": "submitted",
  "data": {
    "app_name": "myapp",
    "port": "3000",
    "environment": "staging",
    "confirmed": "y"
  }
}
```

---

### Capturing and using the result

```bash
result=$(./forms/spawn-decision.sh "Rebuild the index?")
status=$(echo "$result" | jq -r '.status')

if [[ "$status" == "y" ]]; then
    echo "Rebuilding..."
else
    echo "Skipped."
fi
```

```bash
result=$(./forms/spawn-select.sh "dev,staging,prod" "Environment:")
env=$(echo "$result" | jq -r '.value')
echo "Deploying to: $env"
```

```bash
result=$(./forms/spawn-intake.sh fields.json)
if [[ $(echo "$result" | jq -r '.status') == "submitted" ]]; then
    name=$(echo "$result" | jq -r '.data.app_name')
    port=$(echo "$result" | jq -r '.data.port')
fi
```

---

## Running via Claude Code

### Step 1 — Add to CLAUDE.md

Add a section to the project's `CLAUDE.md` that tells the agent when and how
to use each script. Adjust the paths to match where `forms/` lives.

```markdown
## INTERACTIVE DECISIONS

When you need user approval before a destructive or irreversible operation,
do NOT ask in chat. Instead, spawn a decision window:

  FORMS=/usr/local/projects/grabchars-2.0/grabchars/forms

  result=$("$FORMS/spawn-decision.sh" "QUESTION" [default: y|n] [timeout: seconds])
  status=$(echo "$result" | jq -r '.status')

  - If status is "n" or "cancelled": abort and explain in chat.
  - If status is "y": proceed.
  - Destructive operations default to "n". Confirmations default to "y".

Examples where this applies:
  - Deleting files, directories, or database records
  - Overwriting uncommitted changes
  - Pushing to a remote branch
  - Running a migration or schema change


## INTERACTIVE SELECTION

When you need the user to choose from a known set of options:

  result=$("$FORMS/spawn-select.sh" "opt1,opt2,opt3" "PROMPT" [v|h] [default] [timeout])
  value=$(echo "$result" | jq -r '.value')

Use layout "v" for lists longer than 4 items (filter-as-you-type).
Use layout "h" for 2–4 short options (left/right selection).

  - If status is "cancelled": stop and ask the user in chat.


## INTERACTIVE INTAKE

For collecting structured input at the start of a task, write a fields JSON
file and call spawn-intake.sh:

  result=$("$FORMS/spawn-intake.sh" /path/to/fields.json "Form Title")
  data=$(echo "$result" | jq '.data')

  - If status is "cancelled": stop and ask the user what they want to do.
  - If status is "submitted": extract field values from .data and proceed.

Use intake forms when you need 2 or more structured values before starting
work. For a single value, use spawn-decision or spawn-select instead.
```

---

### Step 2 — Invoke from a task

Once the CLAUDE.md is in place, you can ask Claude naturally:

> "Deploy the staging build — ask me to confirm before pushing."

Claude will call `spawn-decision.sh`, a small iTerm2 window will appear,
you press y or n, and Claude proceeds or stops based on the result.

> "Start a new service — collect the name, port, and environment first."

Claude will write a fields JSON for the required inputs, call `spawn-intake.sh`,
and use the returned data to scaffold the service.

---

### Step 3 — Verify it's working

To confirm Claude is using the forms rather than asking in chat, watch for
a new iTerm2 window appearing. The window title will be:
- `❓ Decision` for spawn-decision
- `📋 Select` for spawn-select
- `📝 <title>` for spawn-intake

If Claude asks questions in the chat instead of spawning a window, check
that the CLAUDE.md instructions are loaded (run `/project:init` or start
a new session).

---

## Requirements

- macOS with iTerm2 installed and running
- `grabchars` in PATH (`cargo install grabchars` or download from releases)
- `jq` in PATH — required by spawn-intake.sh and recommended for result parsing
  (`brew install jq`)

---

## Troubleshooting

**"grabchars not found in PATH"** — Install grabchars or add `~/.cargo/bin`
to your PATH before running.

**"failed to spawn iTerm2 window"** — iTerm2 must be running. The scripts do
not launch iTerm2 if it is not already open.

**Window opens but closes immediately** — The runner script may have a syntax
error. Run the script manually and look at the exit output in the window before
it closes, or add `sleep 5` at the end of the generated runner for debugging.

**Result is always `{"status":"error","message":"timed out waiting for window"}`**
— The poll timeout is set to `TIMEOUT + 15` seconds. If the window is taking
longer to appear (slow machine or iTerm2 startup), try increasing the timeout
argument.

See `docs/INTERACTIVE-FORMS.md` for full design rationale and architecture notes.
