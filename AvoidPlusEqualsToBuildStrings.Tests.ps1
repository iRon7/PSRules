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

    Context 'Iterations' {
        It 'For' {
            {
                $Test = $Null
                for ($Index = 0; $Index -lt 9; $Index++) {
                    $Test += 'Test' + $Index
                }
            } | Test-Rule | Should -BeTrue
        }
        It 'Foreach' {
            {
                $Test = ''
                foreach ($Index in 1,2,3) {
                    $Test += 'Test' + $_
                }
            } | Test-Rule | Should -BeTrue
        }
        It 'Foreach method' {
            {
                $Test = ""
                @(1,2,3).foreach{
                    $Test += "Test $_"
                }
            } | Test-Rule | Should -BeTrue
        }
        It 'Foreach-Object' {
            {
                [String]$Test = 0 # Not implemented
                $Test = '0'
                1,2,3 | ForEach-Object {
                    $Test += $_
                }
            } | Test-Rule | Should -BeTrue
        }
        It 'Foreach-Object -Begin' {
            {
                1,2,3 | ForEach-Object -Begin { $Test = $Null } -Process {
                    $Test += "$_"
                }
            } | Test-Rule | Should -BeTrue
        }
        It 'Foreach-Object { ... } { ... }' {
            {
                1,2,3 | ForEach-Object -Begin { $Test = '' } -Process {
                    $Test += $_
                }
            } | Test-Rule | Should -BeTrue
        }
    }

    Context 'Issues' {
        It 'If block' {
            {
                if ($false) {
                    $Test = ''
                    foreach ($Index in 1,2,3) {
                        $Test += $Index
                    }
                }
            } | Test-Rule | Should -BeTrue
        }
    }

    Context 'Negatives' {
        It 'Controlled' {
            {
                $a = ''
                $a += '1'
                $a += '2'
            } | Test-Rule | Should -BeFalse
        }
        It 'Tainted' {
            {
                $Test = ''
                for ($Index = 0; $Index -lt 9; $Index++) {
                    $Test = ''
                    $Test += "$Index"
                }
            } | Test-Rule | Should -BeFalse
        }
        It 'Not defined For' {
            {
                for ($Index = 0; $Index -lt 9; $Index++) {
                    $Test += "x"
                }
            } | Test-Rule | Should -BeFalse
        }
        It 'Not defined ForEach-Object' {
            {
                Get-ChildItem -Path . -Recurse -Filter pom.xml | ForEach-Object {
                    [xml]$pom = Get-Content $_
                    $knownProperties += $pom.project.properties.getEnumerator()
                }
            } | Test-Rule | Should -BeFalse
        }
        It 'Not a string ForEach-Object' {
            {
                $unknownProperties = ''
                $knownProperties = @()
                Get-ChildItem -Path . -Recurse -Filter pom.xml | ForEach-Object {
                    [xml]$pom = Get-Content $_
                    $knownProperties += $pom.project.properties.getEnumerator()
                }
            } | Test-Rule | Should -BeFalse
        }
    }
}