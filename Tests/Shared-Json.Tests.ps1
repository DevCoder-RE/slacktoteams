#Requires -Modules Pester

Describe "Shared-Json" {
    BeforeAll {
        . "$PSScriptRoot\..\Shared\Shared-Json.ps1"
    }

    Context "Read-JsonFile" {
        It "Should read and parse JSON file" {
            $jsonFile = "$TestDrive\test.json"
            $testData = @{ Name = "Test"; Value = 42 }
            $testData | ConvertTo-Json | Out-File -FilePath $jsonFile -Encoding UTF8

            $result = Read-JsonFile -Path $jsonFile
            $result.Name | Should -Be "Test"
            $result.Value | Should -Be 42
        }

        It "Should throw for non-existent file" {
            { Read-JsonFile -Path "$TestDrive\nonexistent.json" } | Should -Throw
        }
    }

    Context "Write-JsonFile" {
        It "Should write object to JSON file" {
            $jsonFile = "$TestDrive\output.json"
            $testData = @{ Key = "Value"; Number = 123 }

            Write-JsonFile -Path $jsonFile -Object $testData

            $content = Get-Content -Path $jsonFile -Raw | ConvertFrom-Json
            $content.Key | Should -Be "Value"
            $content.Number | Should -Be 123
        }

        It "Should create directory if it doesn't exist" {
            $jsonFile = "$TestDrive\subdir\output.json"
            $testData = @{ Test = "Data" }

            Write-JsonFile -Path $jsonFile -Object $testData

            Test-Path $jsonFile | Should -Be $true
        }
    }
}