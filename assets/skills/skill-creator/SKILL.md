---
name: skill-creator
description: Create or improve reusable Kelivo skills from a task, conversation, or existing SKILL.md. Use when the user asks to create, revise, validate, or package a skill.
---

# Skill Creator

Turn a repeatable workflow into a small, importable Kelivo skill. Execute the
workflow first when the user supplied enough information; ask only for a
missing choice that changes the result.

## Extract

Read the current conversation and any existing skill. Identify:

- the trigger and the task boundary;
- inputs, tools, constraints, and expected output;
- decisions that must remain user-controlled;
- a clear completion check.

Treat examples as examples. Generalize a preference only when the user asks
for a reusable rule. Preserve unrelated behavior when updating a skill.

## Design

Keep the entrypoint short and operational. Put the common path in `SKILL.md`.
Move branch-specific detail to a directly linked `references/` file. Add a
`scripts/` file only for a deterministic operation that will be reused; run a
changed script on a small representative input. Add `assets/` only for files
the workflow consumes.

Use lowercase letters, digits, and hyphens for the directory and `name` (64
characters or fewer). Keep the YAML frontmatter to `name` and `description`.
Make the description state both the capability and the user requests that
trigger it. Write body instructions in imperative or infinitive form.

## Deliver

Write a UTF-8 `SKILL.md` with this shape:

```markdown
---
name: example-skill
description: Do one repeatable task. Use when the user asks for that task.
---

# Example Skill

Perform the workflow. Produce the requested output and verify the completion
criteria before reporting the result.
```

Use Kelivo's skill manager boundary for installed skills. When workspace file
tools are available, save the skill in the current workspace and report it as
an importable file; package supporting files as a ZIP only when they are
needed. When file tools are unavailable, return the complete document in one
fenced Markdown block for **Skills -> Import -> Paste**. Do not require
Codex/Claude CLI commands, plugin manifests, subagents, or evaluation runners.

Do not create README, installation guide, quick reference, changelog, or other
process documentation. Do not include private paths, credentials, or stale
environment copies.

## Validate

Before delivery, check all of the following:

1. Frontmatter opens and closes, and `name` matches the directory.
2. Description contains the trigger; the body contains executable steps.
3. Every referenced file exists and every dependency is available or named.
4. No draft placeholders or unrelated files remain.
5. Run one representative request and one nearby request that should not
   trigger the skill. Check objective output requirements and record what was
   actually verified.

Finish with a concise summary of what the skill does, how to import or update
it, and the checks that passed.
