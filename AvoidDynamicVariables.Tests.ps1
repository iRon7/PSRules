#Requires -Modules @{ModuleName="Pester"; ModuleVersion="5.0.0"}

Describe 'UseHyphenMinusForParameters' {

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
            { New-Variable -Name $MyName -Value $Value } | Test-Rule | Should -BeTrue
        }
        It 'VariableExpressionAst' {
            { Set-Variable -Name "Name$i" -Value $Value } | Test-Rule | Should -BeTrue
        }
        It 'VariableExpressionAst' {
            { New-Variable ($Name) } | Test-Rule | Should -BeTrue
        }
    }
    Context 'Negatives' {
        It 'Scope' {
            { Clear-Variable TestVariable* } | Test-Rule | Should -BeFalse
        }
        It 'Scope' {
            { New-Variable -Name $MyName -Value $Value -Scope Local } | Test-Rule | Should -BeFalse
        }
    }
}