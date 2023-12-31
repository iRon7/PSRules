#Requires -Modules @{ModuleName="Pester"; ModuleVersion="5.0.0"}

Describe 'AvoidPlusEqualsToBuildCollections' {

    BeforeAll {
        $RulePath = $PSCommandPath.Replace('.Tests.ps1', '.psm1')
        $RuleName = 'PS' + [io.path]::GetFileNameWithoutExtension($RulePath)

        function Test-Rule {
            Param(
                [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
                [ScriptBlock] $ScriptBlock
            )
            $Result = Invoke-ScriptAnalyzer -CustomRulePath $RulePath -ScriptDefinition $ScriptBlock.ToString()
            $Result.Count -eq 1 -and $Result.RuleName -eq $RuleName
        }
    }

    Context 'Positives' {
        It 'For' {
            {
                $Test = @()
                for ($Index = 0; $Index -lt 9; $Index++) {
                    $Test += [PSCustomObject]@{ Index = $Index }
                }
            } | Test-Rule | Should -BeTrue
        }
        It 'Foreach' {
            {
                $Test = @()
                foreach ($Index in 1,2,3) {
                    $Test += [PSCustomObject]@{ Index = $Index }
                }
            } | Test-Rule | Should -BeTrue
        }
        It 'Foreach method' {
            {
                $Test = @()
                @(1,2,3).foreach{
                    $Test += [PSCustomObject]@{ Index = $Index }
                }
            } | Test-Rule | Should -BeTrue
        }
        It 'Foreach-Object' {
            {
                $Test = @()
                1,2,3 | ForEach-Object {
                    $Test += [PSCustomObject]@{ Index = $_ }
                }
            } | Test-Rule | Should -BeTrue
        }
        It 'Foreach-Object -Begin' {
            {
                1,2,3 | ForEach-Object -Begin { $Test = @() } -Process {
                    $Test += [PSCustomObject]@{ Index = $_ }
                }
            } | Test-Rule | Should -BeTrue
        }
        It 'Foreach-Object { ... } { ... }' {
            {
                1,2,3 | ForEach-Object -Begin { $Test = @() } -Process {
                    $Test += [PSCustomObject]@{ Index = $_ }
                }
            } | Test-Rule | Should -BeTrue
        }
    }

    Context 'Non-empty initiator' {
        It 'Expression Array' {
            {
                $Test = @(0)
                foreach ($Index in 1,2,3) {
                    $Test += [PSCustomObject]@{ Index = $Index }
                }
            } | Test-Rule | Should -BeTrue
        }
        It 'Literal Array' {
            {
                $Test = 1,2,3
                foreach ($Index in 4,5,6) {
                    $Test += [PSCustomObject]@{ Index = $Index }
                }
            } | Test-Rule | Should -BeTrue
        }
    }

    Context 'Issues' {
        It 'PSScriptAnalyzer' { # https://github.com/PowerShell/PSScriptAnalyzer/issues/1933
            {
                $knownProperties = @( )
                Get-ChildItem -Path . -Recurse -Filter pom.xml | ForEach-Object {
                    [xml]$pom = Get-Content $_
                    $knownProperties += $pom.project.properties.getEnumerator() |
                        Where-Object name -ne '#comment' |
                        ForEach-Object name
                    }
            } | Test-Rule | Should -BeTrue
        }
        It 'If block' {
            {
                if ($false) {
                    $Test = @()
                    foreach ($Index in 1,2,3) {
                        $Test += [PSCustomObject]@{ Index = $Index }
                    }
                }
            } | Test-Rule | Should -BeTrue
        }
    }

    Context 'Positive pitfalls' {
        It 'Space in @( )' {
            {
                $knownProperties = @( )
                Get-ChildItem -Path . -Recurse -Filter pom.xml | ForEach-Object {
                    [xml]$pom = Get-Content $_
                    $knownProperties += $pom.project.properties.getEnumerator() |
                        Where-Object name -ne '#comment' |
                        ForEach-Object name
                    }
            } | Test-Rule | Should -BeTrue
        }
    }

    Context 'Suppress' {
        It 'RuleSuppressionID' {
            {
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidPlusEqualsToBuildCollections', 'knownProperties')]
                Param()
                $knownProperties = @( )
                Get-ChildItem -Path . -Recurse -Filter pom.xml | ForEach-Object {
                    [xml]$pom = Get-Content $_
                    $knownProperties += $pom.project.properties.getEnumerator() |
                        Where-Object name -ne '#comment' |
                        ForEach-Object name
                    }
            } | Test-Rule | Should -BeFalse
        }
    }

    Context 'Negatives' {
        It 'Controlled' {
            {
                $a = @()
                $a += 1
                $a += 2
            } | Test-Rule | Should -BeFalse
        }
        It 'Tainted' {
            {
                $Test = @()
                for ($Index = 0; $Index -lt 9; $Index++) {
                    $Test = @()
                    $Test += [PSCustomObject]@{ Index = $Index }
                }
            } | Test-Rule | Should -BeFalse
        }
        It 'Not defined For' {
            {
                for ($Index = 0; $Index -lt 9; $Index++) {
                    $Test += [PSCustomObject]@{ Index = $Index }
                }
            } | Test-Rule | Should -BeFalse
        }
        It 'Not defined ForEach-Object' {
            {
                Get-ChildItem -Path . -Recurse -Filter pom.xml | ForEach-Object {
                    [xml]$pom = Get-Content $_
                    $knownProperties += $pom.project.properties.getEnumerator() |
                        Where-Object name -ne '#comment' |
                        ForEach-Object name
                    }
            } | Test-Rule | Should -BeFalse
        }
        It 'Not an array ForEach-Object' {
            {
                $unknownProperties = @()
                $knownProperties = ''
                Get-ChildItem -Path . -Recurse -Filter pom.xml | ForEach-Object {
                    [xml]$pom = Get-Content $_
                    $knownProperties += $pom.project.properties.getEnumerator() |
                        Where-Object name -ne '#comment' |
                        ForEach-Object name
                    }
            } | Test-Rule | Should -BeFalse
        }
    }
}