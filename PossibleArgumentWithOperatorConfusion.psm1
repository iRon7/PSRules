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
        $Operators = @( # https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_operators

            # Logical Operators
            'and', 'or', 'xor' # https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_logical_operators
            # -not doesn't have a left hand operand

            # Arithmetic Operators
            'band', 'bor', 'bxor', 'shl', 'shr' # https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_arithmetic_operators
            # -bnot doesn't have a left hand operand

            # Equality, see: https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_comparison_operators
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

            # Format operator -f, see: https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_operators#format-operator--f
            'f' # Formats strings by using the format method of string objects
        )
    }
    Process {
        [ScriptBlock]$Predicate = {
            Param ([Ast]$Ast)
            if ($Ast -isnot [CommandAst]) { return $false } 
            if ($Ast.InvocationOperator -ne 'Ampersand') { return $false }
            if ($Ast.CommandElements.Count -lt 3) { return $false }
            if ($Ast.CommandElements[0] -isnot [ScriptBlockExpressionAst] -and
                $Ast.CommandElements[0] -isnot [VariableExpressionAst]) { return $false }
            $Start = $Ast.CommandElements[0].Extent.StartOffset - $Ast.Extent.StartOffset
            $Expression = $Ast.Extent.Text.SubString($Start)
            $Errors = $Null
            $Null = [Parser]::ParseInput($Expression, [ref]$Null, [ref]$Errors)
            return $Errors.Count -eq 0
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
