#Requires -Version 3.0

function Measure-UseHyphenMinusForParameter { # PSUseSingularNouns
<#
    .SYNOPSIS
    Prefix parameters with an unambiguous (ASCII) hyphen-minus.
    .DESCRIPTION
    Hyphen-minus characters are sometimes unintendedly replaced when passed by
    word processors as Microsoft Office applications as MSWord and Outlook.
    It is recommended to prefix parameters with an unambiguous hyphen-minus as
    Unicode dashes might cause parsing errors in earlier versions of PowerShell
    and require a BOM (Byte Order Mark) in script files.
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
            $Ast -is [System.Management.Automation.Language.CommandParameterAst] -and
            [Int][Char]$Ast.Extent.Text[0] -gt 0xff
        }
        $Violations = $ScriptBlockAst.FindAll($Predicate, $False)
        Foreach ($Violation in $Violations) {
            $Extent = $Violation.Extent
            [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]@{
                Message              = "Prefix parameters with a hyphen-minus: -$($Violation.ParameterName)"
                Extent               = $Extent
                RuleName             = 'PSUseHyphenMinusForParameters'
                Severity             = 'Warning'
                RuleSuppressionID    = $Violation.ParameterName
                SuggestedCorrections = [System.Collections.ObjectModel.Collection[Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.CorrectionExtent]](
                    [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.CorrectionExtent]::New(
                        $Extent.StartLineNumber,
                        $Extent.EndLineNumber,
                        $Extent.StartColumnNumber,
                        $Extent.EndColumnNumber,
                        "-$($Violation.ParameterName)" ,
                        'Prefix parameter with a hyphen-minus ("-")'
                    )
                )
            }
        }
    }
}
Export-ModuleMember -Function Measure-*
