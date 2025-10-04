# 🏗️ Migration Architecture

## 🧠 Design Overview

The Slack-to-Teams migration tool is built as a modular pipeline with eight distinct phases. Each phase is implemented as a standalone PowerShell script, allowing for granular control, retries, and preflight testing. This architecture supports both offline and live modes, and is designed to be extensible for future enhancements.

---

## 🔄 Pipeline Phases

| Phase               | Description                                                                 |
|--------------------|-----------------------------------------------------------------------------|
| 1. Discovery        | Scans Slack export to identify channels, users, and metadata               |
| 2. Parse            | Normalizes Slack messages into a unified format                            |
| 3. Map Users        | Resolves Slack user IDs to Microsoft 365 identities                        |
| 4. Provision Teams  | Creates Teams and channels based on Slack structure                        |
| 5. Post Messages    | Sends messages to Teams via Graph API                                      |
| 6. Download Files   | Retrieves Slack files (offline or via API)                                 |
| 7. Upload Files     | Uploads files to Teams and links them to messages                          |
| 8. Validate & Report| Compares source vs target and generates logs and reports                   |

Each script can be run independently or orchestrated via a master script that handles sequencing, error handling, and logging.

---

## ⚙️ Execution Modes

- **Offline Mode**: Uses Slack export files only. Ideal for air-gapped environments.
- **Live Mode**: Uses Slack API and Microsoft Graph API for enhanced fidelity.

Execution mode is controlled via `appsettings.json` or CLI flags. Most phases support both modes, with fallback logic where needed.

---

## 🧩 Key Components

- **Orchestrator Script**: Coordinates pipeline execution, handles retries, and logs progress
- **Config Files**: `.env` and `appsettings.json` control behavior and credentials
- **Mapping Files**: Optional CSVs for user and channel mapping
- **Log Directory**: Stores detailed logs for each phase
- **Report Generator**: Summarizes migration results and highlights discrepancies

---

## 🧪 Testing & Validation

- Each phase includes dry-run and verbose modes
- Validation compares parsed Slack data to posted Teams content
- Logs include timestamps, status codes, and error messages
- Reports highlight missing users, failed posts, and file mismatches

---

## 🔮 Extensibility

The architecture supports future enhancements such as:

- GUI wrapper for non-technical users
- Support for Slack threads, reactions, and attachments
- Integration with Teams Import API
- Packaging as a CLI tool or PowerShell module

