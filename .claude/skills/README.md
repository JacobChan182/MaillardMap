# Claude Teams Skills

This directory contains skill definitions that can be invoked via `/` commands.

## Available Skills

### Development
- `/commit message="..."` - Create formatted git commit
- `/test` - Run test suite
- `/lint` - Run linter
- `/typecheck` - Run TypeScript checks
- `/build` - Build project
- `/format` - Format code with Prettier

### Git & Review
- `/review-pr [number]` - Review PR (current or specified)
- `/create-pr title="..." body="..." [base=main]` - Create PR

### Database
- `/db-migrate` - Run migrations
- `/db-seed` - Seed database

### Docker
- `/docker-build` - Build Docker images
- `/docker-up` - Start containers
- `/docker-down` - Stop containers
- `/logs service=...` - View service logs

### Deployment
- `/deploy env=...` - Deploy to environment
- `/security-scan` - Run security audit

### Documentation
- `/docs-serve` - Serve docs locally

### Agents
- `/agent-run agent=...` - Trigger specific agent

### Contracts & QA
- `/api-contract-check` - Lint OpenAPI spec (auto-detect openapi/swagger file)
- `/e2e-smoke` - Run a backend smoke suite (lint/typecheck/test if present)
- `/api-generate-client` - Generate TypeScript OpenAPI types into backend

### Backend convenience
- `/backend-install` - Install backend dependencies
- `/dev-backend` - Start backend dev server (watch mode)

### Local database
- `/db-up` - Start local Postgres (Docker Compose)
- `/db-down` - Stop local services (Docker Compose)

## Adding New Skills

Add skills to `.claude/settings.json` under the `"skills"` key.

Example:
```json
"skill-name": {
  "description": "What this skill does",
  "command": "command to run",
  "args": [
    {"name": "arg-name", "required": true},
    {"name": "optional-arg", "required": false, "default": "value"}
  ]
}
```
