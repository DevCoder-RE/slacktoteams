# 📤 Phase 7: Upload Files

## 🎯 Purpose

This phase uploads previously downloaded Slack files to Microsoft Teams and links them to their corresponding messages. It ensures that attachments are preserved and accessible in the Teams environment.

---

## 📁 Input

- Local file directory from Phase 6
- `post-summary.json` from Phase 5
- Microsoft Graph API access (required)

---

## 🧠 Logic

The script performs the following steps:

1. **Match Files to Messages**  
   - Uses metadata from parsed messages to associate files with Teams message IDs  
   - Handles multiple attachments per message

2. **Upload to Teams**  
   - Uses Graph API to upload files to the appropriate Teams channel  
   - Stores files in the channel’s SharePoint document library

3. **Link Files to Messages**  
   - Updates message content with file links or previews  
   - Ensures links are accessible to channel members

4. **Log Results**  
   - Tracks upload status, file URLs, and any failures

---

## 🧪 Output

- `upload-summary.json`: List of uploaded files and their Teams URLs  
- Console table: Upload success/failure by channel  
- Logs: API responses, skipped files, and errors

---

## ⚠️ Edge Cases

- Large files may exceed Teams upload limits  
- Duplicate filenames are resolved with suffixes or hashes  
- Files from deleted users may require fallback attribution

---

## 🔮 Future Enhancements

- Support for inline previews and thumbnails  
- Retry logic for failed uploads  
- Option to upload files as message attachments vs SharePoint links  
- Filtering by file type or size

