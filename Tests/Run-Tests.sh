#!/bin/bash

echo "Starting test suite..."

# Test data existence
echo "Testing test data..."
if [ -d "Tests/testdata/slack_export" ]; then
    echo "✓ Slack export test data found"
else
    echo "✗ Slack export test data missing"
fi

if [ -d "Tests/testdata/file_payloads" ]; then
    echo "✓ File payloads test data found"
else
    echo "✗ File payloads test data missing"
fi

# Test phase scripts existence
echo "Testing phase scripts..."
phases=("Phase1-ParseSlack.ps1" "Phase2-MapUsers.ps1" "Phase3-ProvisionTeams.ps1" "Phase4-PostMessages.ps1" "Phase5-DownloadFiles.ps1" "Phase6-UploadFiles.ps1" "Phase7-VerifyMigration.ps1" "Phase8-RetryAndFixups.ps1" "Phase9-ArchiveRun.ps1")

for phase in "${phases[@]}"; do
    if [ -f "Phases/$phase" ]; then
        echo "✓ $phase exists"
    else
        echo "✗ $phase missing"
    fi
done

# Test shared modules
echo "Testing shared modules..."
shared=("Shared-Logging.ps1" "Shared-Config.ps1" "Shared-Json.ps1" "Shared-Retry.ps1" "Shared-Graph.ps1" "Shared-Slack.ps1")

for module in "${shared[@]}"; do
    if [ -f "Shared/$module" ]; then
        echo "✓ $module exists"
    else
        echo "✗ $module missing"
    fi
done

# Test configuration
echo "Testing configuration..."
if [ -f "Config/appsettings.sample.json" ]; then
    echo "✓ Sample config exists"
else
    echo "✗ Sample config missing"
fi

if [ -f "Config/.env" ]; then
    echo "✓ Environment file exists"
else
    echo "⚠ Environment file missing (expected for test)"
fi

# Test mappings
echo "Testing mappings..."
if [ -f "Config/mappings/channels.csv" ]; then
    echo "✓ Channels mapping exists"
else
    echo "✗ Channels mapping missing"
fi

if [ -f "Config/mappings/emoji-map.json" ]; then
    echo "✓ Emoji mapping exists"
else
    echo "✗ Emoji mapping missing"
fi

if [ -f "Config/message-filters.json" ]; then
    echo "✓ Message filters exist"
else
    echo "✗ Message filters missing"
fi

echo "Test suite completed."