## 10. Subagents

Spawn subagents to isolate context, parallelize independent work, or offload bulk mechanical tasks.

**Spawn when:**
- Tasks are independent and have no shared reasoning.
- A subtask is purely mechanical (formatting, extraction, translation).
- Context isolation would prevent contamination between concerns.

**Do not spawn when:**
- The parent needs to hold the reasoning together.
- Synthesis requires cross-task judgment.
- Spawn overhead dominates the actual work.

**Model selection — pick the least capable model that can do the job well:**

| Capability needed | Tier |
|---|---|
| Bulk mechanical, no judgment, high speed | **Gemini Flash** |
| Scoped research, code tasks, repository-wide synthesis | **Gemini Pro** |
| Complex architecture planning, deep reasoning, critical logic | **Gemini Ultra** |

If a subtask turns out to need more capability than its assigned model, the subagent must signal that to the parent — not attempt to compensate.
