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
5. **`CHANGES_REQUESTED`**: QA, Reviewer, or Challenger identified defects; task returned for mutation with failure logs.
6. **`DONE`**: Verified, tested with exit code 0, and integrated into the repository.
7. **`BLOCKED`**: Progress halted due to external dependency, environment crash, or ambiguous requirement.

### Unified Task Handoff Format (v2.0)
When an agent hands off a task or delegates work, the following machine-parseable frontmatter and structured report sections must be used:

```markdown
---
task_id: "[Task Name / ID]"
from: "[Assigning Agent]"
to: "[Target Agent]"
status: "READY" | "IN_REVIEW" | "CHANGES_REQUESTED" | "DONE" | "BLOCKED"
scope_files:
  - "path/to/target/file1" # (Create / Edit)
  - "path/to/target/file2" # (Read / Reference)
acceptance_criteria:
  - id: "AC-1"
    description: "Criterion 1"
    status: "PASS" | "FAIL"
verification_command: "flutter test ... / dart analyze ..."
exit_code: 0
telemetry:
  workspace_total_tests: 0
  workspace_passed_tests: 0
  workspace_failed_tests: 0
  preexisting_failures: 0
  analyzer_issues: 0
---

## 1. Observation & Implementation Summary
Detailed summary of code modifications, new APIs, UI components, and state changes.

## 2. Logic Chain & Verification Evidence
Step-by-step rationale showing how implementation fulfills every acceptance criterion with test outputs.

## 3. Caveats & Residual Risks
Known limitations, external dependencies, or environmental notes. (Note: Environment crashes like ENOSPC or test failures MUST NOT be dismissed as caveats).

## 4. Conclusion & Next Steps
Explicit verdict and clear transition recommendation for the receiving agent.

## 5. Verification Method for Independent Auditors
Exact terminal commands and expected output assertions to independently reproduce verification.
```

### Re-Dispatch & Mutation Protocol (Anti-Ping-Pong)
When a task moves to `CHANGES_REQUESTED`, the orchestrator re-dispatch MUST NOT reuse the original prompt unmodified. It must inject the failure context:

```markdown
### Task Re-Dispatch: [Task Name] (Attempt: {{ATTEMPT_NUMBER}} / Max: 3)
- **Status**: CHANGES_REQUESTED
- **Previous Assignee**: [Previous Worker ID]
- **Rejection Reason**: [Summary of Reviewer/Challenger failure]
- **Failed Test Logs / Stack Traces**:
  ```
  [Raw failure output]
  ```
- **Prohibited Approaches (DO NOT REPEAT)**: [Failed implementation choices]
- **Required Mutation Vector**: [Explicit architectural changes required]
```
*Rule*: If `ATTEMPT_NUMBER > 3`, abort automatic re-dispatch, transition to `BLOCKED`, and escalate to Orchestrator Redesign.

### Deterministic Gate Resolution Algorithm
Milestones evaluated across multiple validators (Reviewers, Challengers, Auditors) are resolved as follows:
1. **Forensic Auditor**: If ANY Auditor reports `INTEGRITY VIOLATION` -> Hard Gate FAIL immediately.
2. **Reviewers**: Requires 100% `APPROVE` on code correctness and architecture. If ANY Reviewer returns `REQUEST_CHANGES` -> state moves to `CHANGES_REQUESTED`.
3. **Adversarial Challengers**: Requires 100% `APPROVE` on test execution. If ANY Challenger writes a failing stress test and returns `REJECT`, the new test MUST be added to the regression test suite and state moves to `CHANGES_REQUESTED`.
4. **Max Review Cycles**: Maximum 2 review cycles per milestone. If consensus is not reached by cycle 2, pause and escalate to User Liaison.

---

## 4. Operational Rules for Multi-Agent Execution

1. **Boundary Isolation & Pre-Handoff Verification**:
   - Agents must only modify files within their assigned scope in `scope_files`.
   - Shared interfaces require explicit Orchestrator sign-off before modification.
   - Pre-Handoff Gate: Prior to submitting handoff, implementing agents and auditors must verify `git status --porcelain` and ensure no unauthorized files have been touched.

2. **Atomic & Documented Changes**:
   - Make focused, granular changes with clear Conventional Commit messages (`feat:`, `fix:`, `refactor:`, `test:`).
   - Do not introduce unrelated refactoring inside a scoped feature task.

3. **Verify Before Handoff & Strict Exit Code Invariant**:
   - No task can move to `IN_REVIEW` or `DONE` without verification (static analysis, tests, or runtime check).
   - All verification commands specified in Acceptance Criteria MUST exit with code 0 (`exit_code == 0`).
   - Environmental errors (ENOSPC disk full, EACCES permission denied, SIGKILL) are BLOCKING FAILURES. They must never be classified as benign caveats to certify completion.

4. **Handling Ambiguity & Subagent Isolation Invariant**:
   - **Subagents (Workers, Reviewers, Challengers, Auditors)**: MUST NEVER attempt to prompt the user directly or wait for interactive input. All ambiguities, blockers, or breaking changes must be reported immediately to the assigning Orchestrator via `send_message` with `status: BLOCKED`.
   - **Top-Level Orchestrator / User Liaison**: Only the root Orchestrator possesses authority to communicate with the user (e.g. via `ask_question`).

5. **Anti-Phantom Execution Invariant for Verification Gates**:
   - Quality and Victory audit phases mandating independent test execution are STRICTLY EMPIRICAL.
   - If an automated command cannot execute (due to sandbox restrictions, missing binaries, or environment permissions), auditors are STRICTLY FORBIDDEN from substituting static code inspection or claiming "Match: YES".
   - The auditor MUST return `VERDICT: VICTORY BLOCKED — TEST EXECUTION ENVIRONMENT RESTRICTED` and escalate to the human user for environment access.

6. **Watchdog Timers & Deadlock Prevention**:
   - Every orchestrator dispatching a background subagent MUST schedule a watchdog timer (e.g., 600s for standard tasks, 1200s for build/test suites) via the `schedule` tool.
   - If a subagent crashes or fails to respond before watchdog expiration, the manager must inspect status via `manage_task`, terminate hanging processes, and trigger recovery rather than hanging indefinitely.

7. **Telemetry Integrity & Failure Transparency**:
   - If repository tests fail anywhere in the workspace (even outside the immediate task scope), the failing test count and files MUST be explicitly propagated in the telemetry block and reported transparently to the user, not silently dropped during summarization.

8. **Global Succession & Recursion Limits**:
   - Orchestrator self-succession is capped at `max_generation_depth = 2` and `max_cumulative_spawns = 32`.
   - When succession occurs, the successor MUST inherit the cumulative spawn count and generation index. If the cap is reached, execution must halt and escalate to the user.
