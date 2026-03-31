---
name: Architecture Decisions
description: Architecture Decision Records (ADRs)
type: project
---

# Architecture Decisions

## ADR-001: Project Structure

**Status**: Accepted
**Date**: 2026-03-30

**Why**: Setting up Claude Teams with multi-agent support for organized development.

**How to apply**: Use `.claude/` directory for all Claude configuration, keep agents focused on specific domains.

## Decisions

| Decision | Status | Notes |
|----------|--------|-------|
| Multi-agent setup | Accepted | Product Architect, Backend, iOS, Android, QA |
| Skills via settings.json | Accepted | 15+ skills defined |
| Git hooks enabled | Accepted | Pre-commit security, post-apply formatting |
