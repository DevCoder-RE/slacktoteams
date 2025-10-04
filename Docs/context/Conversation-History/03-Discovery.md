# 🔍 Phase 1: Discovery

## 🎯 Purpose

The Discovery phase scans the Slack export to identify key entities:
- Channels (public and private)
- Users and their metadata
- Message volumes and timestamps
- File references and attachments

This sets the foundation for downstream phases by building a complete inventory of what needs to be migrated.

---

## 📁 Input

- Slack export directory (unzipped `.zip` from Slack)
- `users.json`, `channels.json`, and per-channel message files
- Optional: `integration_logs.json` and `files.json`

---

## 🧠 Logic

The script performs the following steps:

1. **Load Metadata**  
   Parses `users.json` and `channels.json` to build lookup tables.

2. **Scan Messages**  
   Iterates through each channel’s message file to count messages, detect file references, and collect timestamps.

3. **Build Inventory**  
   Constructs a summary object with:
   - Channel name and type
   - Member count
   - Message count
   - First and last message timestamps
   - File reference count

4. **Log Results**  
   Outputs a summary table and saves a JSON file for use in later phases.

---

## 🧪 Output

- `discovery-summary.json`: Full inventory of channels, users, and files
- Console table: Quick overview of channel activity
- Logs: Any parsing errors or anomalies

---

## ⚠️ Edge Cases

- Private channels may be missing if not included in the export
- Deleted users appear as `unknown` and must be handled in mapping
- Bots and integrations may have non-standard message formats

---

## 🔮 Future Enhancements

- Detect Slack threads and reactions
- Flag inactive or empty channels
- Estimate migration time based on message volume

