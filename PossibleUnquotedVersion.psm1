#Requires -Version 3.0

function Measure-PossibleUnquotedVersion {
<#
    .SYNOPSIS
    Versions need to be quoted.
    .DESCRIPTION
    Version (Date, IPAddress) types need to be quoted otherwise they will be
    seen as a number (double type) with a property member after the second dot.
    .INPUTS
    [System.Management.Automation.Language.ScriptBlockAst]
    .OUTPUTS
    [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]
    .LINK
    https://github.com/PowerShell/PSScriptAnalyzer/issues/1698
    https://github.com/PowerShell/PowerShell/issues/15756
    
#>

    [CmdletBinding()]
    [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord])]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Language.ScriptBlockAst]
        $ScriptBlockAst
    )
    Process {
        [ScriptBlock]$Predicate = {
            Param ([System.Management.Automation.Language.Ast]$Ast)
            $Ast -is [System.Management.Automation.Language.MemberExpressionAst] -and
            $Ast.Extent.Text -Match '^\d\.\d(\.\d)+$'
        }
        $Violations = $ScriptBlockAst.FindAll($Predicate, $False)
        Foreach ($Violation in $Violations) {
            $Extent = $Violation.Extent
            [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]@{
                Message              = "Versions need to be quoted: '$Extent'"
                Extent               = $Extent
                RuleName             = 'PSPossibleUnquotedVersion'
                Severity             = 'Warning'
                RuleSuppressionID    = $Extent.Text
                SuggestedCorrections = [System.Collections.ObjectModel.Collection[Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.CorrectionExtent]](
                    [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.CorrectionExtent]::New(
                        $Extent.StartLineNumber,
                        $Extent.EndLineNumber,
                        $Extent.StartColumnNumber,
                        $Extent.EndColumnNumber,
                        "'$Extent'",
                        "Quote the version: '$Extent'"
                    )
                )
            }
        }
    }
}
Export-ModuleMember -Function Measure-*
