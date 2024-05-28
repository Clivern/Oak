# Contributing to Oak

Thank you for your interest in contributing to Oak! This document provides guidelines and information for contributors.

## Code of Conduct

This project and everyone participating in it is governed by our Code of Conduct. By participating, you are expected to uphold this code.

## How Can I Contribute?

### Reporting Bugs

- Use the GitHub issue tracker
- Include detailed steps to reproduce the bug
- Include your Elixir version and operating system
- Include any relevant error messages or stack traces

### Suggesting Enhancements

- Use the GitHub issue tracker
- Describe the enhancement in detail
- Explain why this enhancement would be useful

### Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass (`mix test`)
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

## Development Setup

```bash
# Clone the repository
git clone https://github.com/clivern/oak.git
cd oak

# Install dependencies
mix deps.get

# Run tests
mix test

# Run linting
mix format

# Generate documentation
mix docs
```

## Testing

- Write tests for new functionality
- Ensure all existing tests pass
- Run the test suite with `mix test`

## Code Style

- Follow Elixir style guidelines
- Use `make fmt` to format your code
- Keep functions small and focused
- Add documentation for public functions

## Documentation

- Update documentation for any API changes
- Add examples for new functionality
- Ensure documentation builds successfully

## Questions?

If you have questions about contributing, feel free to:
- Open an issue on GitHub
- Contact the maintainers

Thank you for contributing to Oak!