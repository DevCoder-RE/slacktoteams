# 💬 Phase 5: Post Messages

## 🎯 Purpose

This phase sends parsed Slack messages to Microsoft Teams channels using the Graph API. It aims to preserve authorship, timestamps, and formatting as closely as possible, while gracefully handling limitations in Teams’ messaging model.

---

## 📁 Input

- `parsed-messages.json` from Phase 2
- `user-map.json` from Phase 3
- `provision-summary.json` from Phase 4
- Microsoft Graph API access (required)

---

## 🧠 Logic

The script performs the following steps:

1. **Load Parsed Messages**  
   Reads normalized messages for each channel.

2. **Resolve Target Channel**  
   Matches Slack channel to Teams channel using provision data.

3. **Format Message Payload**  
   - Applies Teams-compatible markdown  
   - Resolves author identity  
   - Embeds links and emoji  
   - Optionally includes file references

4. **Post via Graph API**  
   - Sends message as delegated user or service account  
   - Handles rate limits and retries  
   - Logs success and failure responses

5. **Track Results**  
   - Records message ID and timestamp  
   - Flags any skipped or failed messages

---

## 🧪 Output

- `post-summary.json`: Status of each posted message
- Console table: Success/failure counts per channel
- Logs: API responses, errors, and skipped entries

---

## ⚠️ Edge Cases

- Teams does not support backdated messages — timestamps reflect posting time  
- Messages from deleted users may be posted as system or fallback account  
- Slack threads are flattened unless explicitly preserved

---

## 🔮 Future Enhancements

- Support for threaded replies in Teams  
- Rich formatting (code blocks, quotes, mentions)  
- Retry queue for failed posts  
- Option to simulate posting for dry runs

