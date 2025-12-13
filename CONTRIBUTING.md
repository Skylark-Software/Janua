# Contributing to Janua

Thank you for your interest in contributing to Janua! This project aims to bring modern RDP support to Apache Guacamole through FreeRDP 3 integration.

## How to Contribute

### Reporting Issues

If you encounter bugs or have feature requests:

1. Check existing [GitHub Issues](https://github.com/Skylark-Software/Janua/issues) to avoid duplicates
2. Create a new issue with:
   - Clear description of the problem or feature
   - Steps to reproduce (for bugs)
   - Your environment (OS, GNOME/KDE version, etc.)
   - Relevant log output

### Submitting Code

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature-name`
3. Make your changes
4. Test thoroughly with your target RDP server (GNOME Remote Desktop, KDE KRdp, etc.)
5. Commit with clear messages explaining the "why"
6. Push to your fork and open a Pull Request

### Code Guidelines

- Keep patches minimal and focused
- Document any new patches in README.md
- Include comments explaining non-obvious code
- Test with multiple RDP targets when possible

### Patch Contributions

When adding new patches to `guacd/patches/`:

1. Use descriptive filenames (e.g., `feature-description.patch`)
2. Include a header comment explaining the purpose
3. Document the patch in the README.md Technical Details section

## Development Setup

```bash
# Clone the repository
git clone https://github.com/Skylark-Software/Janua.git
cd Janua

# Build the guacd image
docker build -t janua-guacd ./guacd

# Test with docker-compose
export POSTGRES_PASSWORD="test-password"
docker-compose up -d
```

## Testing Checklist

Before submitting, please test with available targets:

- [ ] KDE KRdp (Fedora 42+)
- [ ] GNOME Remote Desktop (GNOME 48+)
- [ ] Windows RDP (if available)
- [ ] xrdp (if available)

## Questions?

Feel free to open an issue for questions or discussion about potential contributions.

## License

By contributing, you agree that your contributions will be licensed under the GNU General Public License v3.0.
