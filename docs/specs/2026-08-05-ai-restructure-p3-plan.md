# AI Context Restructure — Sub-project P3 Implementation Plan

> **Execution status — read this before resuming:**
> No tasks executed yet. Start at Task 0 and work through Task 6 in order.

---

## Task 0: Cleanup Placeholder Files
- **Files to remove:** `.ai/agents/OWNERS.md`, `.ai/hooks/OWNERS.md`.
- **Action:** Delete placeholder files created during P1 setup.
- **Commit:** Included in Task 1.

---

## Task 1: Create Custom Skills
- **Files to create:**
  - `.ai/skills/rest-api/SKILL.md`
  - `.ai/skills/event-driven/SKILL.md`
  - `.ai/skills/testing-spring/SKILL.md`
  - `.ai/skills/frontend-component/SKILL.md`
- **Content rules:** Include YAML frontmatter (`name`, `description`). Keep descriptions concise for token efficiency.
- **Commit message:** `docs(ai): add custom skills for rest-api, event-driven, testing, and frontend`

---

## Task 2: Create Subagent Definitions
- **Files to create:**
  - `.ai/agents/architecture-inspector.md`
  - `.ai/agents/migration-specialist.md`
  - `.ai/agents/security-reviewer.md`
- **Content rules:** Detailed role descriptions, core mandates, required checks, and non-negotiable boundaries.
- **Commit message:** `docs(ai): add specialized agent role definitions`

---

## Task 3: Create Automation Hooks
- **Files to create:**
  - `.ai/hooks/pre-commit-verify.sh`
  - `.ai/hooks/post-commit-doc-sync.sh`
- **Action:** Make both scripts executable (`chmod +x`). `pre-commit-verify.sh` executes `scripts/ai-verify.sh --check`.
- **Commit message:** `docs(ai): add pre-commit and post-commit verification hooks`

---

## Task 4: Configure MCP Configuration
- **File to update:** `.ai/mcps/mcp_config.json`.
- **Content:** Valid JSON structure for Model Context Protocol servers.
- **Commit message:** `docs(ai): update MCP configuration template`

---

## Task 5: Extend Link and Verification Tooling
- **Files to update:**
  - `scripts/ai-link.sh` (add `.ai/hooks|.claude/hooks` to link mapping)
  - `scripts/ai-verify.sh` (add `P3-G1`..`P3-G4` checks for skills, agents, MCPs, and hooks)
- **Commit message:** `tools(ai): add P3 verification gates and link configuration`

---

## Task 6: Verification, Symlink Refresh & Development Report
- **Actions:**
  1. Run `bash scripts/ai-link.sh` to refresh all symlinks.
  2. Run `bash scripts/ai-verify.sh` and ensure `exit=0`.
  3. Author development report `docs/reports/master_chore_2026-08-05_ai-restructure-p3.md`.
- **Commit message:** `docs(ai): record P3 migration coverage and development report`
