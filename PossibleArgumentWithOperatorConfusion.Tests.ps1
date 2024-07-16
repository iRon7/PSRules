#Requires -Modules @{ModuleName="Pester"; ModuleVersion="5.0.0"}

Describe 'PossibleArgumentWithOperatorConfusion' {

    BeforeAll {
        $RulePath = $PSCommandPath.Replace('.Tests.ps1', '.psm1')
        $RuleName = 'PS' + [io.path]::GetFileNameWithoutExtension($RulePath)
    }

    Context 'Positives' {
        It 'eq' {
            $Result = Invoke-ScriptAnalyzer -CustomRulePath $RulePath -ScriptDefinition { &{ $Test } -eq 5 }.ToString()
            $Result.Count | Should -Be  1
            $Result.RuleName | Should -Be $RuleName
            $Result.SuggestedCorrections.Text | Should -Be '(&{ $Test }) -eq 5'
        }
        It 'like' {
            $Result = Invoke-ScriptAnalyzer -CustomRulePath $RulePath -ScriptDefinition { &{ "Test" } -like "T?st" }.ToString()
            $Result.Count | Should -Be  1
            $Result.RuleName | Should -Be $RuleName
            $Result.SuggestedCorrections.Text | Should -Be '(&{ "Test" }) -like "T?st"'
        }
        It 'isnot' {
            $Result = Invoke-ScriptAnalyzer -CustomRulePath $RulePath -ScriptDefinition { if (&{ (1,2,3).Where{$_ -eq 4} } -isnot [int]) { Throw "The expression should return an integer" } }.ToString()
            $Result.Count | Should -Be  1
            $Result.RuleName | Should -Be $RuleName
            $Result.SuggestedCorrections.Text | Should -Be '(&{ (1,2,3).Where{$_ -eq 4} }) -isnot [int]'
        }
    }

    Context 'Negatives' {
        It 'Custom argument' {
            $Result = Invoke-ScriptAnalyzer -CustomRulePath $RulePath -ScriptDefinition { &{ $Test } -CustomArgument 5 }.ToString()
            $Result | Should -BeNullOrEmpty
        }
        It 'Switch' {
            $Result = Invoke-ScriptAnalyzer -CustomRulePath $RulePath -ScriptDefinition { &{ $Test } -Contains }.ToString()
            $Result | Should -BeNullOrEmpty
        }
        It 'Corrected' {
            $Result = Invoke-ScriptAnalyzer -CustomRulePath $RulePath -ScriptDefinition { (&{ 1, 2, 3 }) -ne 2 }.ToString()
            $Result | Should -BeNullOrEmpty
        }
    }
}