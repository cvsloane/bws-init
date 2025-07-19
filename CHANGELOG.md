# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-01-19

### Added
- Initial release of bws-init
- Auto-detection of environment files (.env, .env.local, .env.production, etc.)
- Automatic BWS project creation
- Secret upload from environment files
- Secure value generation for placeholder secrets
- Cross-platform support (Windows, Linux, macOS, WSL)
- Retrieval script generation (bash, PowerShell, batch)
- Dry-run mode for previewing changes
- Verbose output option
- Force re-initialization option
- Environment-specific processing (--env flag)
- Custom output directory support
- Comprehensive error handling and logging

### Security
- Automatic generation of cryptographically secure values for:
  - SESSION_SECRET
  - CSRF_SECRET
  - JWT_SECRET
  - ENCRYPTION_KEY
- Detection of placeholder values (your_*, placeholder, example, etc.)

### Documentation
- Comprehensive README with examples
- Quick start guide
- Installation instructions
- CI/CD integration examples
- Troubleshooting guide

[1.0.0]: https://github.com/yourusername/bws-init/releases/tag/v1.0.0