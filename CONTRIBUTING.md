# Contributing

## Goals

- Keep development **fast** and **low-friction**
- Keep the API contract stable for iOS/Android
- Prevent cross-agent merge conflicts by respecting ownership

## Ownership boundaries (important)

- **Backend agent owns**: `backend/`
- **iOS agent owns**: `ios/`
- **Android agent owns**: `android/`
- **Product architect + QA own**: `docs/` (specs + OpenAPI)
- Cross-cutting changes should be coordinated via the OpenAPI contract in `docs/openapi.yaml`.

## Branch naming

- `feat/<short-name>`
- `fix/<short-name>`
- `chore/<short-name>`

## Contract workflow (non-negotiable)

- `docs/openapi.yaml` is the **source of truth** for request/response shapes.
- Any backend endpoint change must update OpenAPI in the **same PR**.
- Regenerate types after contract changes:
  - `/api-generate-client`

## Local checks (before requesting review)

- **Contract**: `/api-contract-check`
- **Backend smoke**: `/e2e-smoke` (runs lint/typecheck/test if present)

If you have Docker Desktop installed:
- **DB**: `/db-up` (starts Postgres)

## Pull request checklist

- [ ] OpenAPI updated (if backend endpoints changed)
- [ ] `/api-contract-check` passed (or warnings acknowledged)
- [ ] `/e2e-smoke` passed
- [ ] No secrets committed (only `.env.example`)
- [ ] iOS/Android behavior matches contract (if applicable)

