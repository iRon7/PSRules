#Requires -Modules @{ModuleName="Pester"; ModuleVersion="5.0.0"}

Describe 'UseHyphenMinusForParameters' {

    BeforeAll {
        $RulePath = $PSCommandPath.Replace('.Tests.ps1', '.psm1')
        $RuleName = 'PS' + [io.path]::GetFileNameWithoutExtension($RulePath)
    }

    Context 'Positives' {
        It 'en-dash' {
            $Result = Invoke-ScriptAnalyzer -CustomRulePath $RulePath -ScriptDefinition { Import-Csv –Path .\Test.csv }.ToString()
            $Result.Count | Should -Be  1
            $Result.RuleName | Should -Be $RuleName
            $Result.SuggestedCorrections.Text | Should -Be '-Path'
        }
        It 'em-dash' {
            $Result = Invoke-ScriptAnalyzer -CustomRulePath $RulePath -ScriptDefinition { Import-Csv —Path .\Test.csv }.ToString()
            $Result.Count | Should -Be  1
            $Result.RuleName | Should -Be $RuleName
            $Result.SuggestedCorrections.Text | Should -Be '-Path'
        }
    }
}