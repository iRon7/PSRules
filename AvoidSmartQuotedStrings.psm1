#Requires -Version 3.0

function Measure-AvoidSmartQuotedString { # PSUseSingularNouns
<#
    .SYNOPSIS
    Avoid surrounding strings with smart quotes.
    .DESCRIPTION
    Quoted strings are sometimes unintendedly replaced when passed by
    word processors as Microsoft Office applications as MSWord and Outlook.
    It is recommended to surround strings with unambiguous single quoted or
    double quoted string as smart quotes require a BOM (Byte Order Mark)
    and therefore it is advised to avoid these characters.
    .INPUTS
    [System.Management.Automation.Language.ScriptBlockAst]
    .OUTPUTS
    [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]
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
            (
                $Ast -is [System.Management.Automation.Language.ExpandableStringExpressionAst] -or (
                    $Ast -is [System.Management.Automation.Language.StringConstantExpressionAst] -and
                    $Ast.StringConstantType -in 'SingleQuoted', 'DoubleQuoted'
                )
            ) -and
            ([Int][Char]$Ast.Extent.Text[0] -gt 0xff -or [Int][Char]$Ast.Extent.Text[-1] -gt 0xff)
        }
        $Violations = $ScriptBlockAst.FindAll($Predicate, $False)
        Foreach ($Violation in $Violations) {
            $Extent = $Violation.Extent
            $Correction = switch ($Violation.StringConstantType) {
                SingleQuoted { "'$($Violation.Value)'" }
                DoubleQuoted { """$($Violation.Value)""" }
            }
            [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]@{
                Message              = "Avoid surrounding strings with smart quotes: $Correction"
                Extent               = $Extent
                RuleName             = 'PSAvoidSmartQuotedStrings'
                Severity             = 'Warning'
                RuleSuppressionID    = $Violation.Value
                SuggestedCorrections = [System.Collections.ObjectModel.Collection[Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.CorrectionExtent]](
                    [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.CorrectionExtent]::New(
                        $Extent.StartLineNumber,
                        $Extent.EndLineNumber,
                        $Extent.StartColumnNumber,
                        $Extent.EndColumnNumber,
                        $Correction,
                        "Surround string with single quotes (') or double quotes ("")"
                    )
                )
            }
        }
    }
}
Export-ModuleMember -Function Measure-*
