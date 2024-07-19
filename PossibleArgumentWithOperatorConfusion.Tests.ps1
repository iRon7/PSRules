#Requires -Modules @{ModuleName="Pester"; ModuleVersion="5.0.0"}

Describe 'PossibleArgumentWithOperatorConfusion' {

    BeforeAll {
        $RulePath = $PSCommandPath.Replace('.Tests.ps1', '.psm1')
        $RuleName = 'PS' + [io.path]::GetFileNameWithoutExtension($RulePath)
    }

    Context 'Positives' {
        It 'ScriptBlock -eq' {
            $Result = Invoke-ScriptAnalyzer -CustomRulePath $RulePath -ScriptDefinition { &{ $Test } -eq 5 }.ToString()
            $Result.Count | Should -Be  1
            $Result.RuleName | Should -Be $RuleName
            $Result.SuggestedCorrections.Text | Should -Be '(&{ $Test }) -eq 5'
        }
        It 'Variable -ne' {
            $Result = Invoke-ScriptAnalyzer -CustomRulePath $RulePath -ScriptDefinition { & $Test -ne "a" }.ToString()
            $Result.Count | Should -Be  1
            $Result.RuleName | Should -Be $RuleName
            $Result.SuggestedCorrections.Text | Should -Be '(& $Test) -ne "a"'
        }
        It 'ScriptBlock -like' {
            $Result = Invoke-ScriptAnalyzer -CustomRulePath $RulePath -ScriptDefinition { &{ "Test" } -like "T?st" }.ToString()
            $Result.Count | Should -Be  1
            $Result.RuleName | Should -Be $RuleName
            $Result.SuggestedCorrections.Text | Should -Be '(&{ "Test" }) -like "T?st"'
        }
        It 'ScriptBlock -isnot' {
            $Result = Invoke-ScriptAnalyzer -CustomRulePath $RulePath -ScriptDefinition { if (&{ (1,2,3).Where{$_ -eq 4} } -isnot [int]) { Throw "The expression should return an integer" } }.ToString()
            $Result.Count | Should -Be  1
            $Result.RuleName | Should -Be $RuleName
            $Result.SuggestedCorrections.Text | Should -Be '(&{ (1,2,3).Where{$_ -eq 4} }) -isnot [int]'
        }
        It 'ScriptBlock -isnot' {
            $Result = Invoke-ScriptAnalyzer -CustomRulePath $RulePath -ScriptDefinition { &{ "{0} {1,-10} {2:N}" } -f 1,"hello",[math]::pi }.ToString()
            $Result.Count | Should -Be  1
            $Result.RuleName | Should -Be $RuleName
            $Result.SuggestedCorrections.Text | Should -Be '(&{ "{0} {1,-10} {2:N}" }) -f 1,"hello",[math]::pi'
        }
        It 'Multiple operators' {
            $Result = Invoke-ScriptAnalyzer -CustomRulePath $RulePath -ScriptDefinition { & $ScriptBlock -eq 1 -and $a -eq 2 }.ToString()
            $Result.Count | Should -Be  1
            $Result.RuleName | Should -Be $RuleName
            $Result.SuggestedCorrections.Text | Should -Be '(& $ScriptBlock) -eq 1 -and $a -eq 2'
        }
        It 'Multiple arithmetic operators' {
            $Result = Invoke-ScriptAnalyzer -CustomRulePath $RulePath -ScriptDefinition { & $a -bor 2 -and 3 }.ToString()
            $Result.Count | Should -Be  1
            $Result.RuleName | Should -Be $RuleName
            $Result.SuggestedCorrections.Text | Should -Be '(& $a) -bor 2 -and 3'
        }
    }

    Context 'Negatives' {
        It 'ScriptBlock -CustomArgument' {
            $Result = Invoke-ScriptAnalyzer -CustomRulePath $RulePath -ScriptDefinition { &{ $Test } -CustomArgument 5 }.ToString()
            $Result | Should -BeNullOrEmpty
        }
        It 'ScriptBlock -Switch' {
            $Result = Invoke-ScriptAnalyzer -CustomRulePath $RulePath -ScriptDefinition { &{ $Test } -Contains }.ToString()
            $Result | Should -BeNullOrEmpty
        }
        It 'Corrected ScriptBlock -ne' {
            $Result = Invoke-ScriptAnalyzer -CustomRulePath $RulePath -ScriptDefinition { (&{ 1, 2, 3 }) -ne 2 }.ToString()
            $Result | Should -BeNullOrEmpty
        }
        It 'Corrected variable -cne' {
            $Result = Invoke-ScriptAnalyzer -CustomRulePath $RulePath -ScriptDefinition { (& $Variable) -cne 2 }.ToString()
            $Result | Should -BeNullOrEmpty
        }
        It 'Corrected variable -cne' {
            $Result = Invoke-ScriptAnalyzer -CustomRulePath $RulePath -ScriptDefinition { & $ScriptBlock -eq 1 -and $This -ButNot $This }.ToString()
            $Result | Should -BeNullOrEmpty
        }
    }
}