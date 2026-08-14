# Multi-Agent Workflow & Task Delegation Guide

This document defines the roles, delegation protocols, and operational workflows for autonomous and semi-autonomous agent collaboration in the **Flash.Ink** repository.

---

## 1. Multi-Agent Architecture

```
                       ┌────────────────────────┐
                       │  Orchestrator Agent    │
                       │ (Architecture & Tasks) │
                       └───────────┬────────────┘
                                   │
         ┌─────────────────────────┼─────────────────────────┐
         ▼                         ▼                         ▼
┌───────────────────┐    ┌───────────────────┐    ┌───────────────────┐
│  Frontend Agent   │    │   Backend Agent   │    │  DevOps / Infra   │
│ (UI / UX / Views) │    │(Logic, Data, APIs)│    │ (CI/CD, Tooling)  │
└─────────┬─────────┘    └─────────┬─────────┘    └─────────┬─────────┘
          │                        │                        │
          └────────────────────────┼────────────────────────┘
                                   ▼
                       ┌────────────────────────┐
                       │   QA & Testing Agent   │
                       │(Validation & Standards)│
                       └────────────────────────┘
```

---

## 2. Agent Roles & Responsibilities

### 🎯 Orchestrator Agent
- **Scope**: Requirement decomposition, architectural decision-making, task assignment, dependency management, and quality control.
- **Responsibilities**:
  - Break down high-level user features into atomic, testable work units.
  - Assign tasks to specialized agents with explicit boundaries and constraints.
  - Coordinate integration points between frontend, backend, and external services.
  - Perform final acceptance checks before closing a task.

### 🎨 Frontend Agent
- **Scope**: User interfaces, interaction design, client-side state, responsiveness, and accessibility.
- **Responsibilities**:
  - Build reusable, responsive, and aesthetically pleasing UI components.
  - Implement client-side routing, data fetching, and state management.
  - Adhere to design tokens, typography, and styling guidelines.
  - Ensure cross-browser compatibility and responsive viewport handling.

### ⚙️ Backend & Data Agent
- **Scope**: Business logic, API design, database schemas, authentication, and integrations.
- **Responsibilities**:
  - Design and implement REST/GraphQL/RPC APIs and service layers.
  - Maintain data persistence models, migrations, and query efficiency.
  - Handle authorization, authentication, input validation, and security sanitization.
  - Manage third-party integrations, background workers, and caching.

### 🧪 QA & Verification Agent
- **Scope**: Automated testing, linting, code analysis, edge-case discovery, and regression prevention.
- **Responsibilities**:
  - Author and run unit, integration, and end-to-end tests for all new features.
  - Validate edge cases, error boundaries, and security vulnerabilities.
  - Ensure code passes static analysis, formatting, and type-checking rules.

### 🚀 DevOps & Tooling Agent
- **Scope**: Build tooling, environment configuration, package management, and CI/CD pipelines.
- **Responsibilities**:
  - Manage repository configs, scripts, and dependency updates.
  - Configure automated build and test pipelines.
  - Maintain reproducible local development and deployment environments.

---

## 3. Task Delegation & Lifecycle Protocol

### Task States
1. **`BACKLOG`**: Requirement drafted but not yet decomposed.
2. **`READY`**: Decomposed into explicit steps with assigned agent and acceptance criteria.
3. **`IN_PROGRESS`**: Active implementation by the assigned agent.
4. **`IN_REVIEW`**: Implementation complete, awaiting QA verification and Orchestrator review.
5. **`DONE`**: Verified, tested, and integrated into the repository.
6. **`BLOCKED`**: Progress halted due to external dependency or ambiguous requirement.

### Task Handoff Format
When an agent hands off a task or delegates work, the following structure must be used:

```markdown
### Task Handoff: [Task Name]
- **From**: [Assigning Agent]
- **To**: [Target Agent]
- **Status**: READY | IN_REVIEW | BLOCKED
- **Context & Goal**: Short summary of what needs to be done and why.
- **Scope & Files**:
  - `path/to/target/file1` (Create / Edit)
  - `path/to/target/file2` (Read / Reference)
- **Constraints & Rules**: Specific constraints, non-negotiable boundaries, or performance requirements.
- **Acceptance Criteria**:
  - [ ] Criterion 1
  - [ ] Criterion 2
- **Verification Command**: e.g., `npm test`, `dart test`, or specific verification steps.
```

---

## 4. Operational Rules for Multi-Agent Execution

1. **Boundary Isolation**:
   - Agents must only modify files within their assigned scope.
   - Shared interfaces (API contracts, type definitions, shared configurations) require explicit Orchestrator sign-off before modification.

2. **Atomic & Documented Changes**:
   - Make focused, granular changes with clear commit messages following Conventional Commits (e.g., `feat:`, `fix:`, `refactor:`, `test:`).
   - Do not introduce unrelated refactoring inside a scoped feature task.

3. **Verify Before Handoff**:
   - No task can move to `IN_REVIEW` or `DONE` without verification (static analysis, tests, or runtime check).
   - If tests fail, the implementing agent must fix the issue before requesting handoff.

4. **Handling Ambiguity & Blockers**:
   - If an agent encounters unspecified behavior, conflicting requirements, or breaking changes, escalate immediately to the Orchestrator or prompt the user for clarification.
