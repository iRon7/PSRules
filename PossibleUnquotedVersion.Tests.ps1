#Requires -Modules @{ModuleName="Pester"; ModuleVersion="5.0.0"}

Describe 'PossibleUnquotedVersion' {

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
        It 'VariableExpressionAst' {
            { $Version = 2.0.9 } | Test-Rule | Should -BeTrue
        }
        It 'VariableExpressionAst' {
            { $Version = [Version]1.2.3.4 } | Test-Rule | Should -BeTrue
        }
    }
    Context 'Negatives' {
        It 'VariableExpressionAst' {
            { $Version = 1.2 } | Test-Rule | Should -BeFalse
        }
        It 'VariableExpressionAst' {
            { $Version = '2.0.9' } | Test-Rule | Should -BeFalse
        }
        It 'VariableExpressionAst' {
            { $Version = "2.0.9" } | Test-Rule | Should -BeFalse
        }
        It 'VariableExpressionAst' {
            { $Version = 1.2.3. } | Test-Rule | Should -BeFalse
        }
    }
}