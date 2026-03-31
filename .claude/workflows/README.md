# Claude Teams Workflows

Standardized workflows for common development tasks.

## Workflows

### Feature Development
See [feature-development.md](feature-development.md) — Standard process for building new features.

### Code Review
High-level review workflow:
1. Self-review with `/lint`, `/typecheck`, `/test`
2. Peer review with `/review-pr`
3. Merge with `/commit` + `/create-pr`

### Hotfix
Fast path for critical fixes:
1. Branch from main
2. Make minimal fix
3. Test locally
4. Fast-track review
5. Deploy immediately

### Refactoring
1. Document current state
2. Plan refactoring with `product-architect` agent
3. Migrate incrementally
4. Validate with tests

## Creating Workflows

Add new workflows as markdown files in this directory:
1. Describe the context
2. List phases/steps
3. Define agent usage
4. Include command examples
5. Add success criteria
