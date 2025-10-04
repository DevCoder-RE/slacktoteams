# Migration Test Checklist

## Pre‑Migration
- [x] Slack export obtained and unzipped
- [x] Azure AD app registered with Graph API permissions
- [x] `config.json` populated with valid credentials

## Phase Tests
- [x] Phase1 parses Slack export without errors
- [x] Phase2 maps all users (no unmapped remain)
- [x] Phase3 provisions all Teams/channels
- [x] Phase4 posts all messages
- [x] Phase5 downloads all files
- [x] Phase6 uploads all files
- [x] Phase7 verification passes
- [x] Phase8 retries clear all failures
- [x] Phase9 archives run successfully

## Post‑Migration
- [x] Spot‑check Teams channels for completeness
- [x] Review logs for warnings/errors
- [x] Confirm archive integrity

## Enhancement Tests
- [x] ChannelFilter parameter works across phases
- [x] UserFilter parameter works across phases
- [x] DeltaMode skips already processed items
- [x] ExecutionMode controls confirmation behavior
- [x] EmailNotifications sends alerts
- [x] Phase skipping works correctly
- [x] API resilience with retries