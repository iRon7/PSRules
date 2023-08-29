#Requires -Modules @{ModuleName="Pester"; ModuleVersion="5.0.0"}

Describe 'UseHyphenMinusForParameters' {

    BeforeAll {
        $RulePath = $PSCommandPath.Replace('.Tests.ps1', '.psm1')
        $RuleName = 'PS' + [io.path]::GetFileNameWithoutExtension($RulePath)
    }

    Context 'Positives' {
        It 'Single smart quotes' {
            $Result = Invoke-ScriptAnalyzer -CustomRulePath $RulePath -ScriptDefinition { Write-Warning ‘Warning’ }.ToString()
            $Result.Count | Should -Be  1
            $Result.RuleName | Should -Be $RuleName
            $Result.SuggestedCorrections.Text | Should -Be "'Warning'"
        }
        It 'Double smart quotes' {
            $Result = Invoke-ScriptAnalyzer -CustomRulePath $RulePath -ScriptDefinition { Write-Warning “Warning” }.ToString()
            $Result.Count | Should -Be  1
            $Result.RuleName | Should -Be $RuleName
            $Result.SuggestedCorrections.Text | Should -Be '"Warning"'
        }
        It 'Smart quoted expression' {
            $Result = Invoke-ScriptAnalyzer -CustomRulePath $RulePath -ScriptDefinition { Write-Warning “$Warning” }.ToString()
            $Result.Count | Should -Be  1
            $Result.RuleName | Should -Be $RuleName
            $Result.SuggestedCorrections.Text | Should -Be '"$Warning"'
        }
    }
}