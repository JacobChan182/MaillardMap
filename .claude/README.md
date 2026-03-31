# BigBack Claude Teams Configuration

This directory contains the Claude Teams configuration for the BigBack project.

## Quick Reference

### Agents (6 defined)
- `architect` - System design (Opus 4.6)
- `frontend` - React/TypeScript UI (Sonnet 4.6)
- `backend` - APIs and services (Sonnet 4.6)
- `devops` - Infrastructure (Sonnet 4.6)
- `qa` - Testing (Sonnet 4.6)
- `reviewer` - Code review (Sonnet 4.6)

### Skills (15+ defined)
- `/commit` - Git commit
- `/review-pr` - Review PR
- `/create-pr` - Create PR
- `/test`, `/lint`, `/typecheck`, `/build` - Development
- `/db-migrate`, `/db-seed` - Database
- `/docker-build`, `/docker-up`, `/docker-down` - Docker
- `/deploy` - Deployment
- `/format`, `/security-scan` - Quality

### Workflows
See [workflows/](workflows/) for standardized processes.

## Directory Structure

```
.claude/
├── settings.json      # Main configuration (agents, skills, hooks)
├── agents/
│   └── README.md      # Agent documentation
├── skills/
│   └── README.md      # Skill documentation
├── hooks/
│   ├── pre-commit.sh  # Pre-commit security check
│   ├── post-apply.sh  # Post-edit formatting
│   └── README.md
├── workflows/
│   ├── README.md
│   └── feature-development.md
└── memory/
    ├── MEMORY.md      # Memory index
    └── *.md           # Memory files
```

## Configuration

Settings are loaded from `.claude/settings.json`:
- **Agents**: Defined under `"agents"` key
- **Skills**: Defined under `"skills"` key
- **Hooks**: Defined under `"hooks"` key

## Usage

### Run an Agent
```
Agent tool with subagent_type="frontend"
prompt: "Build a login form component"
```

### Use a Skill
```
/commit message="feat: add login form"
```

### Follow a Workflow
1. Read the workflow document
2. Invoke agents as specified
3. Use skills at appropriate points

## Extending

Add new agents/skills by editing `.claude/settings.json`.

Add new workflows by creating markdown files in `workflows/`.

Add to memory by creating markdown files in `memory/`.
