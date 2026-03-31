# Feature Development Workflow

A standardized workflow for developing features using Claude Teams.

## Phase 1: Design (`product-architect` agent)

```
Agent: product-architect
Task: Design feature "X"
- Define requirements
- Define data models
- Define API contract (request/response + errors)
- Identify edge cases and non-goals
- Define test plan + acceptance criteria
```

**Output**: Small spec (in PR description or `docs/`) and/or an ADR in `.claude/memory/architecture.md`

## Phase 2: Implementation

### Backend (`backend` agent)
```
Agent: backend
Task: Implement API for feature "X"
- Reference the design document
- Build endpoints
- Write tests
- Update docs
```

### iOS (`ios` agent)
```
Agent: ios
Task: Build iOS for feature "X"
- Reference the design document
- Implement screens/flows
- Wire up API
- Validate map behavior (if applicable)
```

### Android (`android` agent)

```
Agent: android
Task: Build Android for feature "X"
- Reference the design document
- Implement screens/flows
- Wire up API
- Match iOS behavior and edge cases
```

## Phase 3: QA (`qa` agent)

```
Agent: qa
Task: Ensure feature "X" is properly tested
- Review test coverage
- Add E2E tests
- Verify edge cases
- Verify API contract matches spec
- Verify iOS/Android parity for key flows
```

## Phase 4: Merge

```
/review-pr
/commit message="feat: implement feature X"
/create-pr title="..." body="..."
```

## Quick Start Template

```markdown
## Feature: [Name]

### Design
- [ ] Product architect defines spec + API contract

### Implementation
- [ ] Backend builds API
- [ ] iOS builds UI/flows
- [ ] Android builds UI/flows

### Quality
- [ ] QA review
- [ ] Merge
```
