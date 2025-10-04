# 🏢 Phase 4: Provision Teams

## 🎯 Purpose

This phase creates Microsoft Teams and channels that mirror the Slack workspace structure. It ensures that each Slack channel has a corresponding destination in Teams, preserving naming conventions and membership where possible.

---

## 📁 Input

- `discovery-summary.json` from Phase 1
- `user-map.json` from Phase 3
- Optional: `channel-mapping.csv` for manual overrides
- Microsoft Graph API access (required)

---

## 🧠 Logic

The script performs the following steps:

1. **Determine Team Structure**  
   - Groups Slack channels by workspace or topic  
   - Maps each group to a Microsoft Team

2. **Create Teams**  
   - Uses Graph API to provision Teams with appropriate names and descriptions  
   - Adds owners and members based on mapped users

3. **Create Channels**  
   - Creates standard or private channels within each Team  
   - Preserves Slack channel names and visibility

4. **Log Results**  
   - Outputs a summary of created Teams and channels  
   - Flags any failures or permission issues

---

## 🧪 Output

- `provision-summary.json`: List of created Teams and channels
- Console table: Creation status and member counts
- Logs: API responses, errors, and skipped entries

---

## ⚠️ Edge Cases

- Private Slack channels may require manual mapping to private Teams channels  
- Teams naming collisions are resolved with suffixes or overrides  
- Users not found in Microsoft 365 are skipped or flagged

---

## 🔮 Future Enhancements

- Support for channel descriptions and metadata  
- Integration with Teams templates for consistent setup  
- Bulk provisioning via CSV or JSON input

