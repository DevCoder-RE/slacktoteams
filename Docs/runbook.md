# Operations Runbook: Slack to Teams Migration Tool

## Overview
This runbook provides troubleshooting guidance for common issues encountered during Slack to Teams migrations.

## Monitoring Dashboard
Access the monitoring dashboard at: `Dashboard.ps1`

Key metrics to monitor:
- Phase completion status
- API call success rates
- Error counts
- Processing times
- Memory usage

## Common Issues and Solutions

### 1. API Rate Limiting
**Symptoms:**
- Graph API calls failing with 429 status
- Migration slowing down significantly

**Solutions:**
1. Check current API usage in monitoring dashboard
2. Reduce concurrency in config (`Parallel.MaxConcurrency`)
3. Implement exponential backoff (already built-in)
4. Wait for rate limit reset (typically 15 minutes)

**Prevention:**
- Monitor API usage patterns
- Adjust batch sizes in config

### 2. Authentication Failures
**Symptoms:**
- "Invalid token" or "Access denied" errors
- Graph API calls failing with 401/403

**Solutions:**
1. Verify token validity: Check expiry in Azure portal
2. Confirm permissions: Ensure Teams.ReadWrite.All scope
3. Regenerate tokens if expired
4. Check tenant ID configuration

**Prevention:**
- Set up token refresh monitoring
- Use managed identities where possible

### 3. Memory Issues
**Symptoms:**
- Out of memory exceptions
- System slowdown during large channel processing

**Solutions:**
1. Reduce batch sizes in config
2. Enable streaming mode for large files
3. Monitor memory usage in dashboard
4. Restart migration with smaller scope

**Prevention:**
- Test with production-scale data before full migration
- Monitor memory trends

### 4. Data Corruption
**Symptoms:**
- Messages appearing out of order
- Missing attachments
- User mapping failures

**Solutions:**
1. Verify source data integrity
2. Check checkpoint files for corruption
3. Re-run failed phases
4. Validate data accuracy tests

**Prevention:**
- Run data accuracy tests before production
- Implement data validation at each phase

### 5. Network Connectivity
**Symptoms:**
- Timeout errors
- Connection refused

**Solutions:**
1. Check network connectivity to Microsoft 365
2. Verify proxy settings
3. Increase timeout values in config
4. Retry with different endpoints

**Prevention:**
- Test connectivity before starting migration
- Use retry mechanisms

## Alerting

### Automated Alerts
- API failure rate > 5%
- Memory usage > 80%
- Phase stuck for > 30 minutes
- Total errors > 100

### Manual Checks
- Daily review of monitoring dashboard
- Weekly performance trend analysis
- Monthly capacity planning review

## Emergency Procedures

### Complete Migration Failure
1. Stop all running processes
2. Check logs for root cause
3. Restore from last good checkpoint
4. Contact support with log files

### Data Loss Incident
1. Immediately stop migration
2. Assess scope of data loss
3. Restore from backups
4. Notify stakeholders
5. Document incident for post-mortem

## Contact Information
- Development Team: dev-team@company.com
- Operations Team: ops-team@company.com
- Emergency: +1-800-SUPPORT

## Escalation Matrix
- Level 1: Operations team (response < 1 hour)
- Level 2: Development team (response < 4 hours)
- Level 3: Management (response < 24 hours)