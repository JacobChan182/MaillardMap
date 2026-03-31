#!/bin/bash
# Pre-commit hook for Claude Teams
# Runs before Claude applies changes

set -e

echo "🔄 Running pre-commit checks..."

# Check for secrets
echo "  🔒 Checking for secrets..."
if command -v git-secrets &> /dev/null; then
    git-secrets --scan
fi

# Run security scan if npm exists
if [ -f "package.json" ] && command -v npm &> /dev/null; then
    echo "  🔍 Running security audit..."
    npm audit --audit-level=high || true
fi

echo "✅ Pre-commit checks complete"
