# Contributing to SmartTripPlanner

Thank you for your interest in contributing to SmartTripPlanner! This document provides guidelines and instructions for contributing to the project.

## Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment for all contributors.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/yourusername/SmartTripPlanner.git`
3. Set up the development environment following the [README](README.md)
4. Create a feature branch: `git checkout -b feature/my-feature`

## Development Guidelines

### Code Style

- Follow the Swift API Design Guidelines
- Use SwiftLint and SwiftFormat (configured in the project)
- Maintain consistent indentation (4 spaces)
- Keep line length under 120 characters
- Use meaningful variable and function names
- Avoid force unwrapping (`!`) in production code

### Architecture

- Follow the existing modular architecture
- Place new features in the `Features/` directory
- Place business logic in `Services/`
- Keep views focused on UI, not business logic
- Use dependency injection via `DependencyContainer`

### Swift Concurrency

- Use `async/await` for asynchronous operations
- Mark actor-isolated code with `@MainActor` when appropriate
- Avoid using completion handlers; prefer async functions

### Testing

- Write unit tests for new features
- Maintain or improve code coverage
- Place tests in `SmartTripPlannerTests/`
- Use descriptive test names: `test[Feature][Scenario][ExpectedBehavior]`

### Commit Messages

Use conventional commit format:

```
type(scope): subject

body (optional)

footer (optional)
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

Examples:
```
feat(trips): add trip sharing functionality
fix(calendar): resolve event sync issue
docs(readme): update setup instructions
```

## Pull Request Process

1. **Update Documentation**: Ensure README and relevant docs are updated
2. **Run Tests**: All tests must pass
   ```bash
   fastlane test
   ```
3. **Lint Code**: Ensure no linting errors
   ```bash
   fastlane lint
   ```
4. **Format Code**: Run SwiftFormat
   ```bash
   fastlane format
   ```
5. **Create PR**: Submit pull request with clear description
6. **Address Feedback**: Respond to review comments promptly

### PR Template

```markdown
## Description
[Brief description of changes]

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Unit tests added/updated
- [ ] Manual testing completed
- [ ] All tests pass

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] No new warnings
```

## Feature Development

### Adding a New Feature

1. Create feature directory in `Features/`
2. Create view file(s)
3. Create view model (if needed)
4. Add service layer logic in `Services/`
5. Update navigation in `NavigationCoordinator`
6. Add to `ContentView` or appropriate parent
7. Write unit tests
8. Update documentation

### Adding a New Service

1. Create service file in `Services/`
2. Define protocol (if needed for testing)
3. Implement service class
4. Add to `DependencyContainer`
5. Inject into views via `@EnvironmentObject`
6. Write unit tests with mocks

## Testing Guidelines

### Unit Tests

```swift
import XCTest
@testable import SmartTripPlanner

final class MyFeatureTests: XCTestCase {
    var sut: MyFeature!
    
    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        sut = MyFeature()
    }
    
    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }
    
    @MainActor
    func testFeatureBehavior() throws {
        // Given
        let input = "test"
        
        // When
        let result = sut.process(input)
        
        // Then
        XCTAssertEqual(result, "expected")
    }
}
```

### Running Tests

```bash
# All tests
fastlane test

# Specific test
xcodebuild test -project SmartTripPlanner/SmartTripPlanner.xcodeproj \
  -scheme SmartTripPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:SmartTripPlannerTests/MyFeatureTests
```

## Code Review

### As a Reviewer

- Be constructive and respectful
- Focus on code quality, not personal preferences
- Suggest improvements with examples
- Approve when ready, request changes when needed

### As an Author

- Respond to all comments
- Ask for clarification when needed
- Make requested changes or discuss alternatives
- Keep PRs focused and reasonably sized

## Release Process

1. Version bump in Xcode project
2. Update CHANGELOG.md
3. Create release branch: `release/vX.Y.Z`
4. Test thoroughly
5. Merge to `main`
6. Tag release: `git tag vX.Y.Z`
7. Push tag: `git push origin vX.Y.Z`
8. Build and upload to TestFlight: `fastlane beta`

## Issue Reporting

### Bug Reports

Include:
- iOS version
- Device model
- Steps to reproduce
- Expected behavior
- Actual behavior
- Screenshots (if applicable)
- Logs (if available)

### Feature Requests

Include:
- Use case description
- Expected behavior
- Alternative solutions considered
- Mockups (if applicable)

## Resources

- [Swift Style Guide](https://google.github.io/swift/)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [Xcode Documentation](https://developer.apple.com/documentation/xcode)

## Questions?

- Open an issue for questions
- Join discussions in pull requests
- Check existing documentation first

Thank you for contributing! 🎉
