# 🧹 Phase 2: Parse

## 🎯 Purpose

The Parse phase transforms raw Slack messages into a normalized format suitable for posting to Microsoft Teams. Slack messages come in various types and formats — this phase ensures consistency, handles edge cases, and prepares data for mapping and posting.

---

## 📁 Input

- Slack channel message files (`*.json`)
- `users.json` for resolving authorship
- `discovery-summary.json` from Phase 1

---

## 🧠 Logic

The script performs the following steps:

1. **Load Messages**  
   Reads each channel’s message file and flattens nested structures.

2. **Normalize Content**  
   - Converts Slack markdown to Teams-compatible formatting  
   - Resolves user mentions (`<@U12345>`) to display names  
   - Translates emojis to Unicode or descriptive text  
   - Handles attachments, links, and timestamps

3. **Filter Messages**  
   - Removes system messages (e.g., channel joins, bot alerts)  
   - Optionally filters by date range or message type

4. **Build Parsed Output**  
   - Creates a unified message object with:  
     - Author  
     - Timestamp  
     - Text content  
     - Attachments  
     - Reactions (optional)

5. **Log Results**  
   - Outputs a summary of parsed messages  
   - Flags any malformed or skipped entries

---

## 🧪 Output

- `parsed-messages.json`: Normalized messages for each channel
- Console table: Message counts and parsing stats
- Logs: Errors, skipped messages, and formatting issues

---

## ⚠️ Edge Cases

- Slack threads are flattened unless explicitly preserved
- Deleted users appear as `unknown` and must be mapped manually
- Bot messages may lack standard fields

---

## 🔮 Future Enhancements

- Preserve Slack threads as Teams replies  
- Translate reactions and emojis more accurately  
- Support rich formatting (code blocks, quotes, links)

