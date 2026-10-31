---
name: voiremote-agent-note
description: Maintain durable VoiRemote decisions and proposals in .agents/notes, including lifecycle transitions. Use for architectural, device ownership, or distribution decisions; skip mechanical edits.
---

# VoiRemote Agent Notes

Read [Note rules](../../notes/README.md) and search existing notes for the owning decision. Update that note when the decision is unchanged; create a new one only for a different lasting decision.

Use `{lifecycle}/{class}/yyyy-mm-dd-topic.md`, with the original proposal date. Record the problem, actual choice, genuine alternatives and costs. Keep planned hardware behavior in `proposed`, even when its configuration UI or pure policy exists.

On completion, move the file to `implemented`, update `Status`, replace proposal sections with present-tense decisions/consequences, and repair links. Cite executed validation and remaining limits. Rejected proposals state the reason on the status line. Archived notes stay frozen.

Run `make docs-check`. Local wording and mechanical edits do not need an extra Note or approval workflow. A Note never authorizes deployment, driver changes, or publishing.
