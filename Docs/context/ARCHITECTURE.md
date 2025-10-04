# Slack → Microsoft Teams Migration Toolkit

This toolkit automates the migration of Slack workspaces into Microsoft Teams using a multi‑phase PowerShell pipeline.

## 📂 Folder Structure

Phases/ # Phase1–Phase9 scripts (migration steps) 
Shared/ # Helper modules (Logging, JSON, Graph, Slack, Retry) 
Bootstrap/ # Scripts to scaffold a new migration project 
Output/ # Generated data from each phase 
Logs/ # Log files 
Reports/ # Verification and summary reports 
Archives/ # Archived runs 
Tests/ # Test data and checklists


## 🚀 Quick Start

1. **Bootstrap a new project**
   ```powershell
   .\Bootstrap\Bootstrap-NewMigration.ps1 -DestinationPath .\MyMigration
Edit configuration

Update config.json (or appsettings.json) with your Slack and Teams credentials.

Run all phases

.\Bootstrap\Bootstrap-RunAll.ps1 -ProjectRoot .\MyMigration

Verify results

Check Reports and Logs for any errors.

Use Phase8 to retry failed messages/files.

Use Phase9 to archive the run.

Phases Overview
Phase	Script	Purpose
1	Phase1-ParseSlack.ps1	Parse Slack export into structured JSON
2	Phase2-MapUsers.ps1	Map Slack users to Teams accounts
3	Phase3-ProvisionTeams.ps1	Create Teams and channels
4	Phase4-PostMessages.ps1	Post messages into Teams
5	Phase5-DownloadFiles.ps1	Download files from Slack
6	Phase6-UploadFiles.ps1	Upload files to Teams
7	Phase7-VerifyMigration.ps1	Verify migrated content
8	Phase8-RetryAndFixups.ps1	Retry failed items, fix mappings
9	Phase9-ArchiveRun.ps1	Archive logs, outputs, reports
🛠 Dependencies
PowerShell 7+

Microsoft Graph API permissions

Slack API token with export access

📄 License
MIT License — see LICENSE file.

