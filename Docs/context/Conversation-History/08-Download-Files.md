# 📥 Phase 6: Download Files

## 🎯 Purpose

This phase retrieves file attachments referenced in Slack messages. It supports both offline and live modes, allowing flexibility based on the availability of Slack API access and export completeness.

---

## 📁 Input

- `parsed-messages.json` from Phase 2
- Slack export directory (for offline mode)
- Slack API token (for live mode)
- Optional: `files.json` from Slack export

---

## 🧠 Logic

The script performs the following steps:

1. **Identify File References**  
   Scans parsed messages for file URLs, IDs, and metadata.

2. **Download Files**  
   - In **offline mode**, copies files from the Slack export archive  
   - In **live mode**, uses Slack API to download files by ID or URL

3. **Normalize Filenames**  
   - Renames files to avoid collisions  
   - Preserves original names and extensions

4. **Store Locally**  
   - Saves files to a structured directory by channel  
   - Logs download status and errors

---

## 🧪 Output

- `download-summary.json`: List of downloaded files and statuses
- Local file directory: Organized by channel and message
- Logs: API responses, missing files, and skipped entries

---

## ⚠️ Edge Cases

- Some Slack exports omit file content — live mode may be required  
- Private files may require elevated API permissions  
- Duplicate filenames are resolved with suffixes or hashes

---

## 🔮 Future Enhancements

- Support for thumbnails and previews  
- Retry logic for failed downloads  
- Integration with Slack file metadata (`files.json`)  
- Option to skip large files or filter by type

