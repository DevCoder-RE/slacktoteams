# 🧑‍🤝‍🧑 Phase 3: Map Users

## 🎯 Purpose

Slack user IDs must be mapped to Microsoft 365 identities before messages can be posted to Teams. This phase resolves authorship and ensures messages appear with the correct sender attribution.

---

## 📁 Input

- `users.json` from Slack export
- Optional: `user-mapping.csv` (manual overrides)
- Microsoft Graph API access (for live mode)

---

## 🧠 Logic

The script performs the following steps:

1. **Load Slack Users**  
   Parses `users.json` to extract user IDs, display names, emails, and status.

2. **Resolve Microsoft 365 Identities**  
   - In **offline mode**, uses `user-mapping.csv` to match Slack users to Teams users manually.  
   - In **live mode**, queries Microsoft Graph API to find matching users by email or display name.

3. **Handle Unknowns**  
   - Flags deleted or unknown users  
   - Allows fallback to a default sender or service account

4. **Build Mapping Table**  
   - Creates a dictionary of Slack ID → Teams ID  
   - Includes metadata for logging and validation

---

## 🧪 Output

- `user-map.json`: Final mapping of Slack users to Teams identities
- Console table: Match status and resolution method
- Logs: Unmatched users, duplicates, and errors

---

## ⚠️ Edge Cases

- Slack users without email addresses require manual mapping
- Display name collisions may cause ambiguity
- Bots and integrations may not have corresponding Teams identities

---

## 🔮 Future Enhancements

- Interactive mapping UI for manual resolution  
- Support for bulk mapping via Azure AD groups  
- Fallback logic for guest users and external contributors

