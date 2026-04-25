---
name: grape-oas-critique
description: Apply the grape-oas review checklist (six axes — schema correctness, test coverage, boundary violations, backward compatibility, CHANGELOG and PR body, code quality) when reviewing a working tree, branch, or PR in the grape-oas repository. Use when the user asks for a code review, critique, or audit on grape-oas changes — including before opening a PR, before committing, and in chained workflows where the agent reviews its own work before pushing. Output uses Block / Should fix / Consider / Nit severity labels and avoids invented findings.
---

# Critique grape-oas changes

Apply the grape-oas review checklist to the diff in scope (working
tree, named branch, or PR). Read
[agents/code-review.md](../../../agents/code-review.md) and execute
exactly as described:

1. Identify the diff. Default: `git diff main...HEAD`. For a PR
   number or URL, use `gh pr view <N>` / `gh pr diff <N>`. For a
   custom range, use that.
2. Read the relevant files end-to-end (not just the changed lines)
   so the review covers context, not just the patch.
3. Run all six checks in order: schema correctness, test coverage,
   boundary violations, backward compatibility, CHANGELOG / PR body,
   code quality.
4. Report findings using the **Block / Should fix / Consider / Nit**
   labels defined in `agents/code-review.md`. Order by severity,
   blocking findings first. Each finding gets `file:line`, what's
   wrong, and the fix or a concrete question.
5. If you have nothing to say, use the exact template from the
   "When you have nothing to say" section. Do not invent findings to
   look thorough.

Do not soften findings. Do not add encouragement padding. Do not
score the PR. Do not stop at the first problem — run all six checks
every time.
