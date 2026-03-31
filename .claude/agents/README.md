# Claude Teams Agent Definitions

This directory contains custom agent definitions for the BigBack project.

## Available Agents

### product-architect
- **Model**: product-architect
- **Purpose**: Product specs, data models, API contracts, recommendation logic
- **Use when**: Defining requirements, constraints, contracts, and guardrails before implementation

### backend
- **Model**: backend
- **Purpose**: REST API endpoints, DB schema, Foursquare integration, recommendation system
- **Use when**: Implementing backend features, migrations, query design, and performance work

### ios
- **Model**: ios
- **Purpose**: iOS app (Swift), Mapbox integration, UI flows
- **Use when**: Implementing iOS screens/flows, map UX, API integration, performance/UX polish

### android
- **Model**: android
- **Purpose**: Android app (Kotlin), parity with iOS
- **Use when**: Implementing Android screens/flows, matching API behavior, map UX parity

### qa
- **Model**: qa
- **Purpose**: E2E validation and API contract enforcement
- **Use when**: Designing test plans, checking schema/edge cases, validating cross-platform parity

## Usage

Run agents using:
```
Agent tool with subagent_type="agent-name"
```

Pick the agent whose domain matches the work to keep context focused and output consistent with the product guardrails in `CLAUDE.md`.
