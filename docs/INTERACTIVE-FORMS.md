# grabchars — Interactive Forms and Agent Integration

## The problem

Coding agents (Claude Code, Cursor, Copilot, etc.) run shell commands
non-interactively — no TTY. This means any tool that requires direct
terminal input (`dialog`, `fzf`, TUI libraries, and grabchars itself)
cannot be called directly from an agent's bash runner.

The current workaround in most agents is to ask questions in chat.
That works but has real costs: it interrupts the flow, requires the user
to scroll back for context, and clutters the conversation with short
back-and-forth exchanges that could be a single keypress.

grabchars is the right tool for structured, quick input — but only
when it has a TTY to work with.

---

## The spawn pattern

The solution is to let the agent spawn a shell that has a real TTY, run
grabchars there, and communicate results back via temp files. This is not
new: the pattern exists in tools like `interactive-prompt` (see
`experiments/interactive-prompt` in this repo's sibling projects).

```
Agent / Claude Code
    │
    ├──[AppleScript / tmux / terminal]──► New TTY window or pane
    │                                         │
    │                                         ▼
    │                               grabchars runs here
    │                               writes result to /tmp/gc-result.json
    │                               writes /tmp/gc-result.done flag
    │    ◄──[polls for .done]──────────────────┘
    ▼
Agent reads result, continues task
```

The spawn mechanism varies by environment:

| Environment | Spawn method |
|------------|-------------|
| macOS + iTerm2 | `osascript` AppleScript — new window or tab |
| macOS + Terminal.app | `osascript` with Terminal dictionary |
| Any tmux session | `tmux split-window` — 3-line pane at bottom |
| VS Code / Cursor terminal | tmux inside the terminal |
| Remote SSH | Local window SSHes in and runs grabchars there |

The input primitive (grabchars) is the same regardless of spawn method.

---

## Why grabchars and not dialog/fzf/textual

| Tool | Dependency | Binary decisions | Validated fields | Selection menus | Timeout+default | No-Enter input |
|------|-----------|-----------------|-----------------|----------------|----------------|----------------|
| `dialog` | brew install | Yes | No | Yes (checklist) | No | No |
| `fzf` | brew install | No | No | Yes | No | No |
| `textual` (Python) | pip install | No | No | Partial | No | No |
| `grabchars` | cargo install | Yes (`-c yn`) | Yes (`-m`) | Yes (`select`) | Yes (`-t -d`) | Yes |

grabchars is the only tool in this space that handles all five input
patterns, ships as a single binary with no runtime dependencies, and
produces predictable exit codes that scripts can branch on directly.

---

## Use cases for agent integration

### 1. Decision gates

Before any destructive or irreversible operation, the agent spawns a
confirmation window. The timeout defaults to the *safe* choice. The
user has N seconds to intervene; otherwise the conservative path is taken.

```bash
ANSWER=$(grabchars -c yn -d n -t15 -q "Drop table 'users'? [y/N, 15s]: ")
```

This is the most frequent use case. One keypress. The window opens,
the user presses y or n, the window closes. Zero interruption to flow.

Timeout defaults should bias toward safety:
- Destructive operations → default `n`
- Confirmations of desired work → default `y`

### 2. Selection from agent-generated lists

The agent knows things the user must choose from: branches, environments,
test files, recently changed files, deployment targets. Currently agents
present these as numbered lists in chat and wait for a typed reply.
That round-trip is unnecessary.

```bash
# Agent builds the list from git branch, then:
BRANCH=$(grabchars select "main,feature/auth,feature/payments,fix/login" -q "Branch: ")

# Agent lists failing tests:
TEST=$(grabchars select "test_login,test_checkout,test_api_auth" -q "Fix which test: ")

# Short list — horizontal layout
ENV=$(grabchars select-lr "dev,staging,prod" -q "Environment: ")
```

The agent substitutes the comma-separated list dynamically. The user
gets filter-as-you-type for long lists or left/right navigation for
short ones. Result comes back as the selected string.

### 3. Structured intake at session start

Instead of front-loading all questions in chat before starting work,
the agent pops a small intake form:

```bash
APP_NAME=$(grabchars -n30 -r -q "App name: ")
PORT=$(grabchars -m "nnnn" -d "8080" -q "Port: ")
ENV=$(grabchars select "dev,staging,prod" -q "Environment: ")
```

Each field uses the right grabchars mode: free text for names, mask
for ports/dates/phones/codes, select for enumerated choices. Results
go to a temp file the agent reads. No chat round-trip.

### 4. Format-validated fields

Any field with a known structure benefits from mask mode. The mask
enforces the format character by character and auto-inserts literals:

```bash
PHONE=$(grabchars -m "(nnn) nnn-nnnn" -q "Phone: ")     # (212) 555-1212
DATE=$(grabchars -m "nn/nn/nnnn" -q "Date: ")           # 01/15/2026
SERIAL=$(grabchars -m "UUU-nnnnnn" -q "Serial: ")       # ABC-001234
HEX=$(grabchars -m "#xxxxxx" -q "Color: ")              # #a3f0c2
```

The agent receives a valid value or nothing. No post-validation
needed, no "please re-enter your phone number" retry loops.

### 5. Credential and sensitive input

If an agent needs an API key, token, or password, the options today are:
asking in chat (visible in chat history) or reading from a file
(requires prior setup). grabchars with `-s` fills the gap:

```bash
API_KEY=$(grabchars -n64 -r -s -q "API key (silent): ")
```

Silent mode suppresses echo entirely. The value goes to stdout only,
gets written to a temp file the agent reads, and never appears in any
terminal buffer or log. The file is deleted after the agent reads it.

### 6. Hotkey monitoring during long operations

Raw mode (`-R`) captures bytes without escape-sequence parsing. This
makes grabchars useful as a hotkey monitor during long-running
operations — builds, migrations, test runs:

```bash
# Spawn a window showing progress output from a background job.
# grabchars watches for control keys in a loop.
while kill -0 $JOB_PID 2>/dev/null; do
    KEY=$(grabchars -c aqsv -t1 2>/dev/null)
    case "$KEY" in
        a) kill $JOB_PID; echo "Aborted" ;;
        s) signal_skip ;;
        v) VERBOSE=1 ;;
    esac
done
```

Gives the user an abort/skip/verbose control surface without
interrupting the agent.

### 7. Progressive disclosure

Rather than front-loading all questions before starting a multi-step
task, the agent asks each question at the moment it needs the answer:

```
Agent: "Setting up the database layer..."
[spawn] "Use ORM? [y/n]: " → y
Agent: "Which ORM?"
[spawn] "Select: sqlx,diesel,sea-orm,rusqlite" → sqlx
Agent: "Add migrations?"
[spawn] "[y/n]: " → y
```

Each question appears in context, not as a pre-task checklist. The
user understands why each question is being asked.

---

## The forms/ directory

`forms/` contains reusable spawn scripts — thin wrappers that handle
the AppleScript/tmux spawning, polling, and cleanup, so calling code
only needs to express what to ask and what to do with the answer.

### Planned scripts

**`spawn-decision.sh`** — binary y/n

```bash
./forms/spawn-decision.sh "Deploy to production?" n 15
# Returns JSON: {"status": "y"} or {"status": "n"}
```

Simplest case. Spawns a window, runs grabchars with the given question,
timeout, and default. Returns a single-character result.

---

**`spawn-select.sh`** — choose from a list

```bash
./forms/spawn-select.sh "dev,staging,prod" "Environment: "
# Returns JSON: {"status": "selected", "value": "staging"}
```

Spawns grabchars select (vertical) or select-lr (horizontal, for short
lists). Returns the selected option as a string.

---

**`spawn-intake.sh`** — multi-field form

```bash
./forms/spawn-intake.sh fields.json
# fields.json: [{name, type, prompt, mask, choices, default}, ...]
# Returns JSON: {"status": "submitted", "data": {field: value, ...}}
```

Reads a field-spec JSON file. For each field, calls the appropriate
grabchars mode (select, mask, or plain `-n`). Collects all values,
assembles the result JSON, writes the `.done` flag.

Field types: `text` (grabchars -n), `masked` (grabchars -m), `select`,
`select-lr`, `secret` (grabchars -s). Free-form text fields that need
unlimited input fall back to `read -r`.

---

**`spawn-confirm-list.sh`** — show a list of pending changes, confirm

```bash
./forms/spawn-confirm-list.sh "File 1\nFile 2\nFile 3" "Overwrite these files?" n
# Returns JSON: {"status": "y"} or {"status": "n"}
```

Displays a summary before asking the confirmation question. Useful when
the "are you sure?" needs context — agent shows what it's about to do,
then asks for the go-ahead.

---

## CLAUDE.md wiring pattern

Add to any project's CLAUDE.md to give the agent access to the forms
primitives:

```markdown
## INTERACTIVE DECISIONS

When you need user approval before a destructive or irreversible operation,
spawn a decision window rather than asking in chat:

  result=$(./forms/spawn-decision.sh "QUESTION" [default: y|n] [timeout: seconds])
  status=$(echo "$result" | jq -r '.status')
  If status is "n", abort and explain in chat.

## INTERACTIVE SELECTION

When you need the user to choose from a known list:

  result=$(./forms/spawn-select.sh "opt1,opt2,opt3" "PROMPT")
  value=$(echo "$result" | jq -r '.value')

## INTERACTIVE INTAKE

For collecting structured input at the start of a task:

  result=$(./forms/spawn-intake.sh path/to/fields.json)
  data=$(echo "$result" | jq '.data')
  If status is "cancelled", stop and ask the user what they want to do.

Use chat for: open-ended questions, ambiguous requirements, debugging
discussion, anything that needs explanation rather than a value.
```

---

## Relationship to interactive-prompt

The `interactive-prompt` experiment (in the sibling project) established
the spawn architecture: AppleScript + iTerm2 + file-based result passing.
That pattern is sound and reused here unchanged.

The difference is the input primitive. The original scripts use `dialog`
(when available) or bare `read -r`. This forms layer uses grabchars
throughout — for character filtering, validated masks, selection menus,
timeouts with defaults, and silent credential input.

The `tui-form.py` / `textual` approach remains useful for rich multi-field
forms where simultaneous field visibility matters. grabchars-based forms
are sequential (one field at a time) and better suited to short, focused
interactions.

---

## What grabchars is not, in this context

grabchars does not replace a full form library for complex intake. It does
not produce styled output or support multi-line text fields. If you need
the user to write a paragraph, or fill in 10 fields with tab navigation
between them, use textual or dialog.

grabchars is the right tool when the question is short, the answer is
structured, and speed matters. That covers most of what agents actually
need to ask.
