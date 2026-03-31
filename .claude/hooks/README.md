# Claude Teams Hooks

Hooks are shell commands that run automatically at specific points in Claude's workflow.

## Hooks

### pre-commit
- **When**: Before Claude commits changes
- **Purpose**: Validate changes, run checks
- **Current**: Secrets scan, npm audit

### post-apply
- **When**: After Claude applies edits
- **Purpose**: Format code, run linters
- **Current**: Prettier formatting, linting

## Configuration

Hooks are defined in `.claude/settings.json`:

```json
{
  "hooks": {
    "pre-commit": {
      "command": ".claude/hooks/pre-commit.sh",
      "shell": true
    },
    "post-apply": {
      "command": ".claude/hooks/post-apply.sh",
      "shell": true
    }
  }
}
```

## Creating Hooks

1. Create a shell script in this directory
2. Make it executable: `chmod +x script.sh`
3. Add to `settings.json`

## Supported Hook Events

- `pre-commit`: Before committing
- `post-apply`: After applying changes
- `pre-apply`: Before applying changes
