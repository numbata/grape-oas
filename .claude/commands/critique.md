# Critique current changes

Apply the grape-oas review checklist to the working tree (or to the diff
range / PR specified in $ARGUMENTS).

Read [agents/code-review.md](../../agents/code-review.md) and execute
the review exactly as described:

1. Identify the diff. If $ARGUMENTS is empty, use `git diff main...HEAD`.
   If $ARGUMENTS is a PR number or URL, fetch it via `gh`. If
   $ARGUMENTS is a git ref range, use that.
2. Read the relevant files end-to-end (not just the changed lines) so
   the review covers context, not just the patch.
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

Do not soften findings. Do not add encouragement. Do not score the PR.
Do not stop at the first problem — run all six checks every time.
