Master summary document
A single place to understand the solution end‑to‑end, from strategy to mechanics.

High‑level overview
Purpose: Migrate Slack exports into Microsoft Teams with fidelity and control.

Approach: A phase‑based orchestrator with discovery, mapping, transformation, and posting, controlled by config/CLI.

Key capabilities:

Targeting: Channels, users, DMs/MPIMs; date‑range; skip rules by pattern/type/size.

Resilience: Delta runs, offline mode deferral, 429 back‑off, retries.

Auth: Graph interactive or app auth; Slack token verified with scope checks.

Files: Pseudo‑structure preservation, duplicate handling, chunked uploads.

Modes: Import mode default for preserved authorship/timestamps, with override.

Reporting: Inventory outputs, run summaries, optional notifications.

Flow at a glance (ASCII)
Phase 0: Discover inventory → channels, users, files → inventory.json

Phase 1: Parse export → normalized slack_data.json

Phase 2: Map users → Slack IDs → M365 IDs (user_map.json)

Phase 3: Create or reuse Teams targets per layout and privacy settings

Phase 4: Post messages (date‑range + skip rules + authorship/thread fidelity)

Phase 5: Download files (range + skip rules + checksums)

Phase 6: Upload files (duplicate handling + chunked uploads + linking)

Phase 7: Validate and report (coverage, errors, anomalies)

Mermaid diagram (code and rendered)
mermaid
flowchart TD
  A[Phase 0: Discovery] --> B[Phase 1: Parse Export]
  B --> C[Phase 2: Map Users]
  C --> D[Phase 3: Create Teams/Channels]
  D --> E[Phase 4: Post Messages]
  E --> F[Phase 5: Download Files]
  F --> G[Phase 6: Upload Files]
  G --> H[Phase 7: Validate & Report]

  subgraph Controls
    I[Filters: Channel/User/Date Range]
    J[Skip Rules: Patterns/Types/Size]
    K[Modes: Delta/Offline/Import/DM Strategy]
  end

  I --> E
  I --> F
  I --> G
  J --> E
  J --> F
  J --> G
  K --> D
  K --> E
  K --> G
Mid‑level technical details
Authentication:

Graph: Interactive (delegated scopes) or App (client credentials); token fetched once per phase that needs it.

Slack: Token validated via auth.test and scopes via apps.permissions.info; warns on missing scopes.

Configuration precedence: CLI > .env > appsettings.json > defaults; per‑env blocks supported; validation at startup.

Filters:

Date range: Start/End with safe default (365 days) if enabled; applies to messages and optionally files (by message or file timestamp).

Targets: Channels/DMs/All; channel/user filters validated against inventory.

Skip rules: Message text patterns; file types; file size ceilings.

Fidelity options:

Import mode: Default for channels to preserve authorship/timestamps; override posts as service account with “from @user” prefix.

DM strategy: Default to actual Teams chats; alternatives supported via config.

Threads: Replies mapped via thread_ts; fallback to root with prefix if parent ordering issues occur.

Files:

Pseudo‑structure: Channel/thread/date foldering in SharePoint; links posted per config (separate message default).

Duplicates: Suffix strategy (“ (1)”) default.

Chunked uploads: For large files via Graph upload sessions; retry/back‑off on throttling.

Resilience:

Delta runs: State tracks migrated messages/files; re‑runs are idempotent.

Offline mode: Retries then defers; logs and notifications note deferrals.

429 handling: Retry‑After honored; exponential back‑off; jitter supported.

Operator experience:

Inventory commands: ListChannels/ListUsers/ListFiles with table/markdown/CSV.

Selective phases: Start/End/Exclude/Only/Phases CLI.

Notifications: Optional SMTP/Graph sendMail; configurable triggers.