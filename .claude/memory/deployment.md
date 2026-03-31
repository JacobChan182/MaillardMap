---
name: Deployment Guide
description: How to deploy this application
type: reference
---

# Deployment Guide

## Environments

- `development` - Local development
- `staging` - Pre-production testing
- `production` - Live application

## Deployment Commands

```bash
# Deploy to staging
/deploy env=staging

# Deploy to production
/deploy env=production
```

## Docker

```bash
# Build and start all services
/docker-build
/docker-up

# View logs
/logs service=app

# Stop services
/docker-down
```
