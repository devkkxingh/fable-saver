#!/usr/bin/env bash
# fable-saver installer — copies the skill to ~/.claude/skills/ (user level, all projects)
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)/skills/fable-saver/SKILL.md"
DEST_DIR="$HOME/.claude/skills/fable-saver"

if [ ! -f "$SRC" ]; then
  echo "error: SKILL.md not found next to this script — run install.sh from the cloned repo" >&2
  exit 1
fi

mkdir -p "$DEST_DIR"
cp "$SRC" "$DEST_DIR/SKILL.md"

echo "fable-saver installed to $DEST_DIR"
echo "   Start a new Claude Code session, set your model to Fable (/model),"
echo "   then invoke it with: /fable-saver <your task>"
