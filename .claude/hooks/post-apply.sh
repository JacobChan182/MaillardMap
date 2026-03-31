#!/bin/bash
# Post-apply hook for Claude Teams
# Runs after Claude applies changes

set -e

echo "🔄 Running post-apply tasks..."

# Format code if prettier is configured
if [ -f "package.json" ] && [ -f ".prettierrc" ] && command -v npm &> /dev/null; then
    echo "  💅 Formatting code..."
    npm run format -- --write || true
fi

# Run lint if available
if [ -f "package.json" ] && command -v npm &> /dev/null; then
    if npm run | grep -q "lint"; then
        echo "  🔍 Running linter..."
        npm run lint || true
    fi
fi

echo "✅ Post-apply tasks complete"
