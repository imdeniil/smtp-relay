# Contributing to SMTP Relay

First off, thank you for considering contributing to SMTP Relay! It's people like you that make this project great.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
  - [Reporting Bugs](#reporting-bugs)
  - [Suggesting Enhancements](#suggesting-enhancements)
  - [Pull Requests](#pull-requests)
- [Development Setup](#development-setup)
- [Style Guidelines](#style-guidelines)
- [Commit Messages](#commit-messages)
- [Testing](#testing)

## Code of Conduct

This project and everyone participating in it is governed by our Code of Conduct. By participating, you are expected to uphold this code.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues as you might find out that you don't need to create one. When you are creating a bug report, please include as many details as possible:

**Bug Report Template:**

```markdown
**Environment:**
- OS: [e.g., Ubuntu 22.04]
- Docker version: [e.g., 24.0.5]
- Deployment mode: [Full Stack / SMTP-only]
- STARTTLS: [enabled / disabled]

**Describe the bug:**
A clear and concise description of what the bug is.

**To Reproduce:**
Steps to reproduce the behavior:
1. Run command '...'
2. See error

**Expected behavior:**
A clear description of what you expected to happen.

**Logs:**
```
Paste relevant logs here
```

**Additional context:**
Add any other context about the problem here.
```

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, please include:

- **Use a clear and descriptive title**
- **Provide a step-by-step description** of the suggested enhancement
- **Provide specific examples** to demonstrate the steps
- **Describe the current behavior** and **explain the behavior you expected** instead
- **Explain why this enhancement would be useful**

### Pull Requests

1. **Fork the repository** and create your branch from `main`
2. **Make your changes** following our style guidelines
3. **Test your changes** thoroughly
4. **Update documentation** if needed
5. **Commit your changes** with clear commit messages
6. **Push to your fork** and submit a pull request

## Development Setup

### Prerequisites

- Docker 20.10+
- Docker Compose 2.0+
- Bash 4.0+
- Git

### Setup Steps

```bash
# Clone your fork
git clone https://github.com/yourusername/smtp-relay.git
cd smtp-relay

# Make scripts executable
chmod +x *.sh

# Copy example configuration
cp .env.example .env

# Edit configuration for testing
nano .env

# Run deployment
./deploy.sh
```

### Testing Your Changes

```bash
# Test deployment
./deploy.sh

# Test management commands
./manage.sh status
./manage.sh health
./manage.sh tls-check

# Test SSL symlinks functionality
./manage.sh fix-ssl-symlinks

# Check logs for errors
./manage.sh logs

# Clean up
./manage.sh clean
```

## Style Guidelines

### Shell Script Style

- Use `#!/bin/bash` shebang
- Use 4 spaces for indentation (no tabs)
- Use `set -e` for error handling
- Add comments for complex logic
- Use meaningful variable names in UPPER_CASE
- Add function documentation

**Example:**

```bash
#!/bin/bash

set -e

# Function description
# Arguments:
#   $1 - description of first argument
# Returns:
#   0 on success, 1 on failure
my_function() {
    local arg=$1
    
    # Implementation
    echo "Processing: $arg"
    
    return 0
}
```

### Documentation Style

- Use Markdown for all documentation
- Use clear, descriptive headings
- Include code examples where appropriate
- Keep lines under 100 characters when possible
- Use tables for comparing options
- Include both Russian and English versions where applicable

### Docker Compose Style

- Use YAML version 3.8
- Add comments for each service
- Use descriptive service names
- Specify restart policies
- Include health checks
- Add logging configuration

## Commit Messages

### Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- **feat**: A new feature
- **fix**: A bug fix
- **docs**: Documentation changes
- **style**: Code style changes (formatting, etc.)
- **refactor**: Code refactoring
- **test**: Adding or updating tests
- **chore**: Maintenance tasks

### Examples

```
feat(manage): add SSL symlink fixing command

- Added fix_ssl_symlinks() function to manage.sh
- Automatically detects certificate volume
- Creates symlinks and verifies STARTTLS

Closes #123
```

```
fix(deploy): check for actual certificate files

Previously checked for symlinks which didn't exist yet.
Now checks for actual certificate files in the directory.

Fixes #456
```

```
docs(ssl): add comprehensive SSL troubleshooting guide

Created SSL-CERTIFICATES-FIX.md with:
- Problem description and symptoms
- Automatic and manual solutions
- Diagnostic procedures
- Technical details
```

## Testing

### Manual Testing Checklist

Before submitting a PR, please test:

- [ ] Fresh deployment with Full Stack mode
- [ ] Fresh deployment with SMTP-only mode
- [ ] STARTTLS functionality
- [ ] SSL symlink creation
- [ ] `./manage.sh` commands:
  - [ ] status
  - [ ] health
  - [ ] tls-check
  - [ ] fix-ssl-symlinks
  - [ ] add-user
  - [ ] test (send email)
- [ ] Backup and restore
- [ ] Clean and redeploy

### Integration Testing

```bash
# Run all integration tests
./test-remote.sh your-domain.com 6025 test@example.com password

# Or use the simple test
./test-remote-simple.sh your-domain.com 6025 test@example.com password
```

## Documentation Updates

When adding new features, please update:

1. **README.md** - Main documentation
2. **CHANGELOG.md** - Add entry under Unreleased
3. **manage.sh help** - If adding new commands
4. **.env.example** - If adding new configuration options
5. **SSL-CERTIFICATES-FIX.md** - If related to TLS/certificates
6. **OPTIMIZATION-REPORT.md** - For significant improvements

## Questions?

Feel free to:
- Open an issue with the `question` label
- Start a discussion in GitHub Discussions
- Check existing documentation in `/docs` directory

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to SMTP Relay! 🎉
