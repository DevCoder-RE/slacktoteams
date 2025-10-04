# ADR 001: Graph API Batching Implementation

## Status
Accepted

## Context
The Slack to Teams migration tool was experiencing performance bottlenecks when creating multiple Teams channels and posting messages individually via the Microsoft Graph API. Each API call introduced network latency and was subject to rate limiting, resulting in slow migration times for large workspaces.

## Decision
Implement Graph API batching to group multiple operations into single HTTP requests, reducing the number of API calls and improving overall migration performance.

## Implementation Details

### Batch Request Structure
- Use Microsoft Graph's `$batch` endpoint to combine multiple operations
- Group operations by type (channel creation, member addition, message posting)
- Limit batch size to 20 requests per batch to stay within API limits

### Functions Added
- `Invoke-GraphBatchRequest`: Core batch execution function
- `New-BatchedTeamChannels`: Batch channel creation
- `Add-BatchedTeamMembers`: Batch member addition
- `Send-BatchedChannelMessages`: Batch message posting

### Error Handling
- Individual request failures within a batch don't fail the entire batch
- Fallback to individual API calls if batch fails
- Maintain existing retry logic for batch operations

## Consequences

### Positive
- Significant reduction in API calls (up to 20x fewer requests)
- Improved migration speed for large workspaces
- Better resilience to rate limiting

### Negative
- Increased complexity in request construction
- Potential for partial batch failures requiring individual retry
- Memory overhead for building batch payloads

### Performance Impact
- Expected 3-5x improvement in channel provisioning speed
- 2-3x improvement in message posting throughput
- Reduced API rate limit consumption

## Alternatives Considered
1. **Individual API calls with rate limiting**: Simple but slow
2. **Concurrent individual calls**: Risk of rate limit violations
3. **Custom batching library**: Would require additional dependencies

## Testing
- Unit tests for batch request construction
- Integration tests with mock Graph API responses
- Performance benchmarks comparing batched vs individual calls

## References
- Microsoft Graph API Batch documentation
- Current implementation in Shared-Graph.ps1