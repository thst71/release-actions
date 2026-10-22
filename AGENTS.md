# Workspace Guidelines & Rules

release-actions holds the GitHub Actions that release a project from a signed tag. This file holds the project's facts and rules; the workflows are skills in `.agents/skills/`.

## How to Work Here

1. **Environment**: Before the first terminal command, apply [environment](.agents/skills/environment/SKILL.md).
2. **Skills**: Before a matching task, read the skill and follow it. Load the referenced skills and profiles only when a step needs them.

| Task | Skill |
|---|---|
| New feature, from idea to backlog | [create-new-feature](.agents/skills/create-new-feature/SKILL.md) |
| Requirement / tech specification / user story | [create-requirement](.agents/skills/create-requirement/SKILL.md), [create-tech-specification](.agents/skills/create-tech-specification/SKILL.md), [create-user-story](.agents/skills/create-user-story/SKILL.md) |
| Change of existing specification items | [update-feature](.agents/skills/update-feature/SKILL.md), [update-requirement](.agents/skills/update-requirement/SKILL.md), [update-user-story](.agents/skills/update-user-story/SKILL.md) |
| Implement a story | [implement-user-story](.agents/skills/implement-user-story/SKILL.md) |
| Fix a defect | [fix-bug](.agents/skills/fix-bug/SKILL.md) |
| Done check | [definition-of-done](.agents/skills/definition-of-done/SKILL.md) |
| Commit | [commit](.agents/skills/commit/SKILL.md) |
| Release | [release](.agents/skills/release/SKILL.md) |
| Commands, test tooling | [toolchain](.agents/skills/toolchain/SKILL.md) |
| Specification layout and rules | [spec-system](.agents/skills/spec-system/SKILL.md) |

## Precedence

1. This file.
2. The project skills in `.agents/skills/`.
3. Personal instructions and skills of the user (e.g. `~/.claude/skills`, `~/.agents/`). They may only cover the machine environment and how to communicate; they never override a project rule or a project skill of the same purpose.

`.agents/skills/` is the vendored agent-skills library (`git subtree`); adapt it here, under "Project Facts", never by editing it. Update it with `git subtree pull --prefix .agents/skills git@thst71.github.com:thst71/agent-skills.git main --squash`.

---

## Project Facts

### Components

| Path | Toolchain profile |
|---|---|
| `.` (`*/action.yml`, `*/*.sh`, `test/`) | none; the commands below |

Contract tasks in `Taskfile.yml`: `lint` (actionlint, shellcheck), `test` (the three scripts in `test/`), `validate-specs` (agent-skills launcher), `check`. There is no `format-check` and no `typecheck`.

### Conventions

- Each action is a composite `action.yml` that passes its inputs as environment variables to one bash script next to it; the logic lives in the script.
- Scripts run with bash 3.2 (macOS) and 5: no associative arrays, no `mapfile`, no `globstar`; guard empty arrays under `set -u` with `${a[@]+"${a[@]}"}`.
- Errors go to stderr as `::error::<message>` and exit 1.

### Test Pyramid Limits

- `test/verify_test.sh` signs tags with throw-away keys and overrides the signing program locally (`gpg.ssh.program=ssh-keygen`), never touching the user's 1Password setup.
- `test/publish_test.sh` and `test/render_test.sh` need Docker; with Colima, set `TMPDIR` below the home directory. The render test needs `spec-validator` (or `VALIDATOR=<command>`).
- A real release is tested by releasing this repository.

### Commit Scopes

`verify`, `render`, `publish`, `workflow`, `agents`.

---

## Self-Correction & Debugging Protocol

- **Do Not Guess**: Read stack traces and error messages carefully before editing code.
- **Isolate**: Reproduce defects with a minimal automated test before modifying code.
- **Limit Loops**: If a test or build fails more than 3 times for the same reason, stop and ask the user for guidance.
- **Zero Unapproved Dependencies**: Use what the runners and the pinned asciidoctor image provide; do not add tools unless specified in the technical specification or requested by the user.
