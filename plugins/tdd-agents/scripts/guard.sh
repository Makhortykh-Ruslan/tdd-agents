#!/bin/bash
# PreToolUse hook on Edit|Write. Plugin subagents ignore frontmatter hooks,
# so one guard serves both roles and tells them apart by agent_type.
#   test-writer — may write test files only.
#   implementer — may not touch tests or switch lint / the type checker off.
# Any other agent, including the main session, passes.
input=$(cat)
agent=$(jq -r '.agent_type // ""' <<<"$input")
file=$(jq -r '.tool_input.file_path // ""' <<<"$input")
# Edit sends the new text in new_string, Write in content
text=$(jq -r '(.tool_input.new_string // "") + (.tool_input.content // "")' <<<"$input")

is_test() {
  case "$1" in *.test.*|*.spec.*|*/__tests__/*|*/e2e/*) return 0 ;; esac
  return 1
}

case "$agent" in
  tdd-agents:test-writer)
    is_test "$file" && exit 0
    echo "test-writer: only test files may be written. Production code is the implementer's job: $file" >&2
    exit 2
    ;;
  tdd-agents:implementer)
    if is_test "$file"; then
      echo "implementer: tests are read-only. Make the code pass the test, do not change the test: $file" >&2
      exit 2
    fi
    # "as any" as whole words, so "was anything" passes
    if grep -qE 'eslint-disable|@ts-ignore|@ts-expect-error|(^|[^[:alnum:]_])as any([^[:alnum:]_]|$)' <<<"$text"; then
      echo "implementer: switching off lint or the type checker is not allowed. Fix the code instead." >&2
      exit 2
    fi
    ;;
esac
exit 0
