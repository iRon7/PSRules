#Requires -Version 3.0

using namespace System.Management.Automation.Language

function Measure-AvoidDynamicVariable { # PSUseSingularNouns
<#
    .SYNOPSIS
    Avoid dynamic variables using the *-Variable (as Get-Variable and Set-Variable) cmdlets.
    .DESCRIPTION
    Using  Get-Variable, Set-Variable and New-Variable cmdlets for creating dynamic variables is
    a bad practice as they will be added to the same dictionary which might cause confusion and
    cause other static variables to be overwritten.
    Instead use dictionary (as a hash table) to define a custom list of dynamic variables.
    .INPUTS
    [System.Management.Automation.Language.ScriptBlockAst]
    .OUTPUTS
    [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]
    .LINK
    https://github.com/PowerShell/PSScriptAnalyzer/issues/1706
    https://stackoverflow.com/a/68830451/1701026
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
            if ($Ast -isnot [CommandAst]) { return $false }
            if ($Ast.CommandElements[0] -isnot [StringConstantExpressionAst]) { return $false }
            $CommandName = $Ast.CommandElements[0].Value
            if ($CommandName -notmatch '^[a-z]+\-Variable$' ) { return $false }
            $Parameters = @{}
            $CommandElement = $Null
            $ParameterIndex = 0
            foreach ($Element in $Ast.CommandElements) {
                if (!$CommandElement -and $Element -is [StringConstantExpressionAst]) {
                    $CommandElement = $Element
                }
                elseif ($Element -is [ExpressionAst]) {
                    if ($ParameterName) { $Parameters[$ParameterName] = $Element }
                    else { $Parameters[$ParameterIndex++] = $Element }
                }
                $ParameterName = if ($Element -is [CommandParameterAst]) { $Element.ParameterName }
            }
            if (
                !$Parameters.Count -or 
                $Parameters.get_Keys().where({ $_ -notin 'Name', 'Value', 0, 1 }, 'first' )
            ) { return $false }
            $Expression =
                if ($Parameters.ContainsKey('Name')) { $Parameters['Name'] }
                elseif ($Parameters.ContainsKey(0))  { $Parameters[0] }
            $Expression -isnot [StringConstantExpressionAst]
        }
        $Violations = $ScriptBlockAst.FindAll($Predicate, $False)
        Foreach ($Violation in $Violations) {
            $Extent = $Violation.Extent
            [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]@{
                Message              = "Avoid creating dynamic variables using the *-Variable cmdlets"
                Extent               = $Extent
                RuleName             = 'PSAvoidDynamicVariables'
                Severity             = 'Warning'
                RuleSuppressionID    = $Violation.CommandElements[0].Value
            }
        }
    }
}
Export-ModuleMember -Function Measure-*
