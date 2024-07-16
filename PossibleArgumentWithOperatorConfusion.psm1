#Requires -Version 3.0

using namespace System.Management.Automation.Language

function Measure-PossibleArgumentWithOperatorConfusion {
<#
    .SYNOPSIS
    Possible argument with operator confusion.
    .DESCRIPTION
    Use of &, the call operator, starts a command and is therefore parsed in argument mode;
    what follows the command name / path is invariably interpreted as arguments to pass to it.

    As with any command, if you want it to participate in an expression, you need to enclose it in (...)
    .INPUTS
    [System.Management.Automation.Language.ScriptBlockAst]
    .OUTPUTS
    [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]
    .LINK
    https://github.com/PowerShell/PSScriptAnalyzer/issues/2014
    https://github.com/PowerShell/PowerShell/issues/24054
#>

    [CmdletBinding()]
    [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord])]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ScriptBlockAst]
        $ScriptBlockAst
    )
    Begin {
        $Operators = @(
            # Equality
            'eq', 'ieq', 'ceq' # equals
            'ne', 'ine', 'cne' # not equals
            'gt', 'igt', 'cgt' # greater than
            'ge', 'ige', 'cge' # greater than or equal
            'lt', 'ilt', 'clt' # less than
            'le', 'ile', 'cle' # less than or equal

            # Matching
            'like', 'ilike', 'clike' # string matches wildcard pattern
            'notlike', 'inotlike', 'cnotlike' # string doesn't match wildcard pattern
            'match', 'imatch', 'cmatch' # string matches regex pattern
            'notmatch', 'inotmatch', 'cnotmatch' # string doesn't match regex pattern

            # Replacement
            'replace', 'ireplace', 'creplace' # replaces strings matching a regex pattern

            # Containment
            'contains', 'icontains', 'ccontains' # collection contains a value
            'notcontains', 'inotcontains', 'cnotcontains' # collection doesn't contain a value
            'in' # value is in a collection
            'notin' # value isn't in a collection

            # Type
            'is' # both objects are the same type
            'isnot' # the objects aren't the same type
        )
    }
    Process {
        [ScriptBlock]$Predicate = {
            Param ([Ast]$Ast)
            if ($Ast -isnot [CommandAst]) { return $false } 
            if ($Ast.InvocationOperator -ne 'Ampersand') { return $false }
            if ($Ast.CommandElements.Count -ne 3) { return $false }
            if ($Ast.CommandElements[0] -isnot [ScriptBlockExpressionAst]) { return $false }
            if ($Ast.CommandElements[1] -isnot [CommandParameterAst]) { return $false }
            return $Ast.CommandElements[1].ParameterName -in $Operators
        }
        $Violations = $ScriptBlockAst.FindAll($Predicate, $False)
        Foreach ($Violation in $Violations) {
            $Extent = $Violation.Extent
            $Operator = $Violation.CommandElements[1].Extent.Text
            $ScriptBlockEnd = $Violation.CommandElements[0].Extent.EndOffset - $Violation.Extent.StartOffset
            $Correction = "($($Extent.Text.Substring(0, $ScriptBlockEnd)))$($Extent.Text.Substring($ScriptBlockEnd))"
            [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]@{
                Message              = "Possible argument with operator ($Operator) confusion."
                Extent               = $Extent
                RuleName             = 'PSPossibleArgumentWithOperatorConfusion'
                Severity             = 'Warning'
                RuleSuppressionID    = $Violation.Value
                SuggestedCorrections = [System.Collections.ObjectModel.Collection[Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.CorrectionExtent]](
                    [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.CorrectionExtent]::New(
                        $Extent.StartLineNumber,
                        $Extent.EndLineNumber,
                        $Extent.StartColumnNumber,
                        $Extent.EndColumnNumber,
                        $Correction,
                        "Surround the call operator and ScriptBlock with parenthesis: (...)"
                    )
                )
            }
        }
    }
}
Export-ModuleMember -Function Measure-*
