#Requires -Modules @{ModuleName="Pester"; ModuleVersion="5.0.0"}

Describe 'AvoidRuleSuppression' {

    Context 'Positives' {
         It 'Write-Host' {
            $Expression = {
                [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
                Param()
                Write-Host 'Test'
            }.ToString()
            $Results = Invoke-ScriptAnalyzer -ScriptDefinition $Expression -CustomRulePath .\AvoidRuleSuppression.psm1
            $Results | Should -not -BeNullOrEmpty
            $Results.RuleName | Should -BeLike 'PSAvoidRuleSuppression *'
        }
    }
}