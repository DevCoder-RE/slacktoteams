# Architectural Decision Record: Epic 3 - Advanced Migration Features

## Context
Epic 3 enhances the Slack to Teams migration tool with advanced features: message threading preservation, rich text formatting conversion, reaction and emoji migration, and user permission mapping. These features address gaps in basic migration, ensuring data fidelity and user experience continuity.

## Decision
Implement threading by parsing Slack's `thread_ts` field, sorting messages chronologically, posting root messages first, then replies using Teams reply API. Enhance markdown conversion to handle code blocks, inline code, and lists. Extract reactions from Slack messages and post them to Teams messages. Map Slack user roles (owner/admin) to Teams roles and assign during team provisioning.

## Alternatives Considered
- Batch posting for threads: Rejected due to API limitations requiring individual posting for replies.
- Advanced mention mapping: Deferred due to Teams mention API complexity.
- Full emoji mapping: Simplified to basic reactions (like, heart) for reliability.

## Consequences
- Positive: Improved data fidelity, better user experience.
- Negative: Individual posting slower than batch, potential rate limiting.
- Risks: API changes, incomplete reaction mapping.

## Implementation Details
- Phase1: Parse thread_ts and reactions.
- Phase2: Add role mapping.
- Phase3: Assign owners during provisioning.
- Phase4: Sort and post messages with replies and reactions.
- Shared-Slack: Enhanced markdown converter.
- Shared-Graph: Added reply and reaction functions.

## Testing
- Unit tests for parsing and conversion.
- Integration tests with mock APIs.
- Performance tests for large datasets.

## Future Considerations
- Real-time reaction syncing.
- Advanced mention handling.
- Custom emoji migration.