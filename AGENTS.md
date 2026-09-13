# Behavioral Guidelines

Reduce common LLM coding mistakes. Merge with project-specific instructions as
needed; project instructions take precedence where they are more specific.

## Core Principles

### 1. Think Before Coding

State assumptions explicitly. If uncertainty materially changes the result, ask.
Present multiple plausible interpretations when they exist and resolve ambiguity
before writing code.

### 2. Simplicity First

Implement only what was requested. Add no speculative features or abstractions for
single-use code. If a senior engineer would call the solution overcomplicated,
simplify it.

### 3. Surgical Changes

Restrict edits to the direct requirements. Do not improve adjacent code, comments,
or formatting without cause. Remove only dead code created by the change and
preserve the existing style.

### 4. Goal-Driven Execution

Transform requests into measurable success criteria before implementation. Convert
vague directives such as "fix the bug" into concrete checks: reproduce it with a
test, implement the fix, and prove the test and project quality gate pass.
Use GPT-5.6 Luna subagents for implementation. Spawn subagents only with the
`gpt-5.6-luna` model; this rule applies to all nested subagents as well.

## Shared Cross-Project Learnings

At the start of each session, read `~/.codex/LEARNINGS.md` before project work. It
is the shared canonical learning file used by both Codex and Claude. Follow it in
addition to this file and project-specific instructions.

When a lesson clearly generalizes across projects, propose a terse addition in chat
and wait for explicit approval before editing the shared file. Never add
project-specific facts, credentials, or transient debugging details.
