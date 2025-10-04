#Requires -Modules Pester

Describe "Shared-Config" {
    BeforeAll {
        . "$PSScriptRoot\..\Shared\Shared-Config.ps1"
        . "$PSScriptRoot\..\Shared\Shared-Logging.ps1"
        . "$PSScriptRoot\..\Shared\Shared-Json.ps1"
    }

    Context "Load-DotEnv" {
        It "Should load environment variables from .env file" {
            # Create a temporary .env file
            $envFile = "$TestDrive\.env"
            @"
TEST_VAR1=value1
TEST_VAR2=value2
# Comment
empty=
"@ | Out-File -FilePath $envFile -Encoding UTF8

            Load-DotEnv -Path $envFile

            $env:TEST_VAR1 | Should -Be "value1"
            $env:TEST_VAR2 | Should -Be "value2"
        }

        It "Should handle non-existent file gracefully" {
            Load-DotEnv -Path "$TestDrive\nonexistent.env"
            # Should not throw
        }
    }

    Context "Get-Config and Set-Config" {
        BeforeEach {
            $Global:AppConfig = @{
                Test = @{
                    Nested = "value"
                }
            }
        }

        It "Should get nested config value" {
            $result = Get-Config -Key "Test.Nested"
            $result | Should -Be "value"
        }

        It "Should return default for missing key" {
            $result = Get-Config -Key "Missing.Key" -Default "default"
            $result | Should -Be "default"
        }

        It "Should set config value" {
            Set-Config -Key "New.Key" -Value "newvalue"
            $result = Get-Config -Key "New.Key"
            $result | Should -Be "newvalue"
        }
    }

    Context "Checkpoint functions" {
        BeforeEach {
            $checkpointDir = "$TestDrive\Checkpoints"
            if (Test-Path $checkpointDir) { Remove-Item $checkpointDir -Recurse }
        }

        It "Should save and load checkpoint" {
            $state = @{ TestData = "test" }
            Save-Checkpoint -Phase "TestPhase" -State $state -CheckpointDir "$TestDrive\Checkpoints"

            $loaded = Load-Checkpoint -Phase "TestPhase" -CheckpointDir "$TestDrive\Checkpoints"
            $loaded.State.TestData | Should -Be "test"
            $loaded.Phase | Should -Be "TestPhase"
        }

        It "Should return null for non-existent checkpoint" {
            $result = Load-Checkpoint -Phase "NonExistent" -CheckpointDir "$TestDrive\Checkpoints"
            $result | Should -Be $null
        }
    }
}