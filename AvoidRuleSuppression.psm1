#Requires -Version 3.0

using namespace System.Management.Automation.Language

function Measure-AvoidSecureStringDisclosure {
<#
    .SYNOPSIS
    Avoid rule suppression

    .DESCRIPTION
    Scripts that suppress rules should note left unnoticed.

    .INPUTS
    [System.Management.Automation.Language.ScriptBlockAst]

    .OUTPUTS
    [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]

    .LINK
    https://github.com/dotnet/platform-compat/blob/master/docs/DE0001.md
#>

    [CmdletBinding()]
    [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord])]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ScriptBlockAst]
        $ScriptBlockAst
    )
    Process {
        [ScriptBlock]$Predicate = {
            Param ([Ast]$Ast)
            (
                $Ast -is [AttributeAst] -and
                $Ast.TypeName.FullName -eq 'System.Diagnostics.CodeAnalysis.SuppressMessageAttribute'
            )
        }
        $Violations = $ScriptBlockAst.FindAll($Predicate, $False)
        Foreach ($Violation in $Violations) {
            $Extent = $Violation.Extent
            [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]@{
                Message              = "Avoid rule suppression: $Extent"
                Extent               = $Extent
                RuleName             = 'PSAvoidRuleSuppression ' + [Guid]::NewGuid().Guid
                Severity             = 'Information'
                RuleSuppressionID    = $null
            }
        }
    }
}
Export-ModuleMember -Function Measure-*
