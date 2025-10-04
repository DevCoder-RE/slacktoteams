# ✅ Phase 8: Validate & Report

## 🎯 Purpose

This final phase verifies the success of the migration and generates summary reports. It compares source Slack data with posted Teams content, flags discrepancies, and provides logs for audit and troubleshooting.

---

## 📁 Input

- `parsed-messages.json` from Phase 2  
- `post-summary.json` from Phase 5  
- `upload-summary.json` from Phase 7  
- Microsoft Graph API access (optional for live validation)

---

## 🧠 Logic

The script performs the following steps:

1. **Compare Message Counts**  
   - Slack vs Teams per channel  
   - Flags missing or failed posts

2. **Validate File Uploads**  
   - Confirms file links are present and accessible  
   - Checks for missing or duplicate uploads

3. **Generate Summary Report**  
   - Aggregates success/failure stats  
   - Highlights skipped users, channels, and files  
   - Includes timestamps, error codes, and retry attempts

4. **Optional Live Validation**  
   - Queries Teams channels via Graph API  
   - Confirms presence of messages and attachments

---

## 🧪 Output

- `validation-report.json`: Detailed comparison of Slack vs Teams content  
- `migration-summary.md`: Human-readable summary for stakeholders  
- Logs: All discrepancies, errors, and retry outcomes

---

## ⚠️ Edge Cases

- Slack timestamps cannot be preserved exactly in Teams  
- Deleted or unknown users may skew authorship stats  
- File links may expire or require permissions

---

## 🔮 Future Enhancements

- Visual dashboards for migration metrics  
- Export to CSV or HTML for reporting  
- Integration with Teams audit logs  
- Notification system for post-run alerts

