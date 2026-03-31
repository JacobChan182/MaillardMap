# BigBack

Mobile social app (iOS + Android) with a Node.js REST API.

This repo is intentionally structured so each Claude agent has a **clear, owned workspace**.

## Development

### Prerequisites
- Node.js
- Docker (optional)

### Getting Started

#### Backend

```bash
cd backend
npm install
npm run dev
```

Health check: `GET http://localhost:3000/health`

#### Docs (OpenAPI)

The OpenAPI stub lives at `docs/openapi.yaml`.

You can lint it with `/api-contract-check`.

## Contributing

See `CONTRIBUTING.md` for the contract workflow, ownership boundaries, and PR checklist.

### Claude Skills

| Command | Description |
|---------|-------------|
| `/commit` | Create git commit |
| `/test` | Run tests |
| `/build` | Build project |
| `/lint` | Run linter |
| `/format` | Format code |
| `/api-contract-check` | Lint OpenAPI spec |
| `/e2e-smoke` | Backend smoke suite |

### Available Agents

| Agent | Purpose |
|-------|---------|
| `product-architect` | Specs, data models, API contracts, recommendation heuristics |
| `backend` | Node.js REST API, DB schema, integrations |
| `ios` | SwiftUI app (MVVM) |
| `android` | Kotlin app (MVVM) |
| `qa` | Contract + integration testing |

### Agents Usage

```
Agent tool with subagent_type="frontend"
prompt: "Create a dashboard component"
```

## Project Structure

```
├── .claude/           # Claude Teams configuration
│   ├── settings.json  # Agents, skills, hooks
│   ├── agents/        # Agent docs
│   ├── skills/        # Skill docs
│   ├── hooks/         # Git hooks
│   ├── workflows/     # Development workflows
│   └── memory/        # Project memory
├── backend/           # Backend agent owns (Node.js/TS REST API)
├── ios/               # iOS agent owns (SwiftUI MVVM)
├── android/           # Android agent owns (Kotlin MVVM)
└── docs/              # Specs + OpenAPI
```

## License

MIT
