# Language Rules

Communication with the user must follow these rules:

- Responses to the user must be written in **Brazilian Portuguese (pt-BR)**.
- All **documentation and Markdown files must be written in English** unless explicitly defined as a translation.
- **Code comments must be written in English.**
- Do not mix Portuguese and English inside the same documentation file.

Examples:

User explanation → Portuguese  
README / docs → English  
Code comments → English  

---

# Git Rules

AI agents must **NOT execute or simulate Git operations**.

Do NOT:

- run git commands
- create commits
- generate commit messages
- suggest git workflows unless explicitly requested

Version control is handled **manually by the user**.

AI agents should only:

- create files
- modify files
- propose changes

---

# Scope of Changes

AI agents must:

- modify only files relevant to the task
- avoid unnecessary refactors
- avoid large rewrites unless explicitly requested
- preserve the existing architecture and project structure

Prefer **small and precise changes**.

---

# Dependency Rules

Before introducing new dependencies:

- verify if the functionality already exists
- prefer native language features
- avoid adding heavy libraries

If a dependency is necessary:

- explain why it is needed
- keep the dependency minimal

---

# Code Quality

Generated code must:

- follow existing project conventions
- prioritize readability
- avoid unnecessary abstractions
- use clear naming conventions

---

# Documentation Rules

Documentation must follow these standards:

- Documentation files must be written in **English**
- Keep documentation clear and concise
- Follow **GitHub README conventions**
- Use Markdown best practices

Documentation files must be placed **in the project root unless otherwise specified**.

---

# README.md Requirements

The project must contain a `README.md` file in the **root directory**.

The README must follow **standard GitHub structure**:

Recommended sections:

- Project title
- Description
- Badges relevant to the project
- Features
- Installation
- Usage
- Configuration
- Contributing
- License (if applicable)

Badges should be **relevant to the project**, for example:

- language version
- CI status
- license
- package version
- code coverage

Avoid adding irrelevant badges.

---

# README Translation

A Portuguese translation of the README must exist.

Files:

```

README.md
LEIAME.md

```

Rules:

- `README.md` → English version
- `LEIAME.md` → Brazilian Portuguese translation

Both files must contain **a link to the counterpart language**.

Example in `README.md`:

```

📄 Portuguese version: see LEIAME.md

```

Example in `LEIAME.md`:

```

📄 English version: see README.md

```

The translation should preserve:

- section structure
- headings
- code examples

---

# Contributing Documentation

The project must include contribution guidelines.

Files:

```

CONTRIBUTING.md
CONTRIBUINDO.md

```

Rules:

- `CONTRIBUTING.md` → English
- `CONTRIBUINDO.md` → Brazilian Portuguese

Both files must contain **a link to the other language version**.

Example:

In `CONTRIBUTING.md`:

```

📄 Portuguese version: see CONTRIBUINDO.md

```

In `CONTRIBUINDO.md`:

```

📄 English version: see CONTRIBUTING.md

```

---

# Markdown File Signature

All Markdown files (`*.md`) created in this repository must end with the following signature:

```

---

Made with ❤️ and AI by [Kadu Velasco](https://github.com/kaduvelasco)

```

This signature must appear **at the end of the file**.

"Ensure the signature is only added once at the very end, even if the file is edited multiple times."

Files affected include:

- README.md
- LEIAME.md
- CONTRIBUTING.md
- CONTRIBUINDO.md
- documentation files
- any other Markdown documentation

---

# Security Practices

AI agents must never:

- expose credentials
- generate secrets
- commit API keys
- introduce insecure patterns

---

# General Principles

AI agents working in this repository should:

- respect the project structure
- keep changes minimal
- generate maintainable code
- avoid unnecessary complexity
- focus only on the requested task
```

