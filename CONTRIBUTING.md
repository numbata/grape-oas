# Contributing to Grape::OAS

We welcome contributions to Grape::OAS! This document provides guidelines for contributing.

## Getting Started

1. **Fork the repository** on GitHub

2. **Clone your fork**:
   ```bash
   git clone https://github.com/YOUR_USERNAME/grape-oas.git
   cd grape-oas
   ```

3. **Set up upstream remote**:
   ```bash
   git remote add upstream https://github.com/numbata/grape-oas.git
   ```

4. **Install dependencies**:
   ```bash
   bin/setup
   ```

## Development Workflow

1. **Create a topic branch**:
   ```bash
   git checkout -b my-feature
   ```

2. **Write tests** for your changes in `test/`

3. **Implement your feature or fix**

4. **Run the test suite**:
   ```bash
   bundle exec rake test
   ```

5. **Run RuboCop**:
   ```bash
   bundle exec rubocop
   ```

6. **Run all checks**:
   ```bash
   bundle exec rake
   ```

## Submitting Changes

1. **Update CHANGELOG.md** under "Unreleased" section

2. **Write clear commit messages** describing what and why

3. **Push to your fork**:
   ```bash
   git push origin my-feature
   ```

4. **Open a Pull Request** against the `main` branch

## Pull Request Guidelines

- Keep PRs focused on a single change
- Include tests for new functionality
- Update documentation if needed
- Ensure CI passes before requesting review

## Code Style

- Follow existing code conventions
- RuboCop enforces style - run it before committing
- Use descriptive variable and method names

## Testing

- Write tests for all new functionality
- Ensure existing tests pass
- Aim for good coverage of edge cases

## Questions?

Open an issue for questions or discussions about potential changes.

Thank you for contributing!
