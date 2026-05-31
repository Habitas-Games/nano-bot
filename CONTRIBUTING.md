# Contributing to nano-bot

Thanks for your interest in contributing! This guide explains how to report bugs, suggest features, and submit code.

---

## Getting started

1. **Fork** the repo on GitHub
2. **Clone** your fork locally
3. **Create a branch** for your changes: `git checkout -b fix/my-bug` or `feature/my-idea`
4. **Make your changes** and test them
5. **Push** to your fork and **open a pull request**

---

## Reporting bugs

**Before opening an issue**, check if it's already reported at [GitHub Issues](https://github.com/mnavas/nano-bot/issues).

### Bug report template

```
## Description
[Clear description of the bug]

## Steps to reproduce
1. [Step 1]
2. [Step 2]
3. [...]

## Expected behavior
[What should happen]

## Actual behavior
[What actually happens]

## Environment
- Godot version: [e.g., 4.6.1]
- OS: [e.g., macOS 13, Ubuntu 22.04]
```

---

## Suggesting features

Feature requests welcome. Describe:
- **What problem** does it solve?
- **How would you use it?**
- **Any alternatives** you've considered

Open an issue with the `enhancement` label and describe your idea clearly.

---

## Code changes

### Style guidelines

- **GDScript**: Follow [GDScript best practices](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/index.html)
  - Use `var name: Type = value` (explicit typing)
  - Use 4-space indentation
  - Classes and constants: `PascalCase`
  - Functions and variables: `snake_case`
  - Private members: prefix with `_` (e.g., `_internal_state`)

- **HTML**: Minimal, semantic, self-contained (no external dependencies)
- **Markdown**: 80-char line limit, consistent heading hierarchy

### Testing

Before submitting a PR, run the test suite:

```bash
godot4 --path . --headless -s test_sim.gd
godot4 --path . --headless -s test_full_gui_path.gd
```

If you add a new feature that's user-facing, consider adding a test or updating the participant guide.

### Commit messages

Keep commits atomic and describe **why**, not just what:

```
Fix movement cost calculation in bloodstream cells

Previously, NanoBot bots were ignoring the −2 turn bonus when
moving with the bloodstream current, causing pathfinding to
underestimate optimal routes.

Fixes #42
```

---

## Pull request checklist

- [ ] Tests pass (`godot4 --headless -s test_*.gd`)
- [ ] Code follows the style guide
- [ ] Commit messages are clear and atomic
- [ ] I've updated docs if my changes affect the API or player-facing behavior
- [ ] No breaking changes (or breaking changes are discussed in the PR)

---

## Areas for contribution

### High-impact

- **New bot types** — design, stats, behavior (discuss in an issue first)
- **Map design** — create interesting 50×50 maps with varied terrain, bloodstreams, and Habitas Point layouts
- **Strategy examples** — write and share novel strategies in `strategies/`
- **Tournament mode improvements** — better bracket visualization, stats tracking

### Medium-impact

- **Documentation** — clarity, examples, translations
- **Participant guide examples** — walkthrough of specific strategies or tactics
- **Bug fixes** — reported issues in the issue tracker
- **UI polish** — replay viewer, main menu, HUD refinements

### Low-barrier

- **GitHub stars & shares** — helps others discover the project
- **Feedback** — "I tried this strategy and it works because…"
- **Typo fixes** — docs, code comments, error messages

---

## Questions?

- Check the [participant guide](docs/participant_guide.html)
- Review existing [issues](https://github.com/mnavas/nano-bot/issues) and [PRs](https://github.com/mnavas/nano-bot/pulls)
- Open a discussion or issue labeled `question`

---

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
