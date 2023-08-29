#Requires -Version 3.0

using namespace System.Management.Automation.Language

function Measure-AvoidPlusEqualsToBuildSting { # PSUseSingularNouns
<#
    .SYNOPSIS
    Avoid using the Assignment by Addition Operator to build a collection
    .DESCRIPTION
    Array addition is inefficient because arrays have a fixed size. Each addition to the array
    creates a new array big enough to hold all elements of both the left and right operands.
    The elements of both operands are copied into the new array. For small collections, this
    overhead may not matter. Performance can suffer for large collections.
    .INPUTS
    [System.Management.Automation.Language.ScriptBlockAst]
    .OUTPUTS
    [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]
    .LINK
    https://github.com/iRon7/PSRules
    https://github.com/PowerShell/PSScriptAnalyzer/issues/1934
    https://learn.microsoft.com/powershell/scripting/dev-cross-plat/performance/script-authoring-considerations
    https://stackoverflow.com/a/60708579/1701026
#>

    [CmdletBinding()]
    [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord])]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Language.ScriptBlockAst]
        $ScriptBlockAst
    )
    Begin {
        function IsString([Ast]$Expression, [switch]$OrNull) {
            if ($OrNull -and $Expression -is [VariableExpressionAst] -and $Expression.VariablePath.UserPath -eq 'Null') { return $true }
            While (
                $Expression -is [BinaryExpressionAst] -or
                $Expression -is [ParenExpressionAst]
            ) {
                if (
                    $Expression -is [BinaryExpressionAst] -and
                    $Expression.Operator -eq 'Plus'
                ) { $Expression = $Expression.Left }
                else { # $Expression -is [ParenExpressionAst]
                    $Expression = $Expression.Pipeline.PipelineElements[0].Expression
                }
            }
            $Expression -is [ExpandableStringExpressionAst] -or (
                $Expression -is [StringConstantExpressionAst] -and
                $Expression.StringConstantType -in 'SingleQuoted', 'DoubleQuoted'
            ) -or (
                $Expression -is [ConvertExpressionAst] -and
                $Expression.StaticType.Name -eq 'String'
            )
        }
        function GetEquals ([String]$VariableName, [Ast]$Statement) {
            If ($Statement -is [NamedBlockAst] -or $Statement -is [StatementBlockAst]) {
                $Container = $Statement
                $Index = $Container.Statements.Count
            }
            else {
                $Container = $Statement.Parent
                if ($Container -isnot [NamedBlockAst]) { return }
                $Index = 0
                While ($Container.Statements[$Index].Extent.StartOffset -lt $Statement.Extent.StartOffset) { $Index++ }
            }
            $EqualsStatement = $Null
            While (--$Index -ge 0) {
                $EqualsStatement = $Container.Statements[$Index]
                if (
                    $EqualsStatement -is [AssignmentStatementAst] -and
                    $EqualsStatement.Operator -eq 'Equals' -and
                    $EqualsStatement.Left.VariablePath.UserPath -eq $VariableName
                ) { break }
            }
            if ($Index -ge 0) { $EqualsStatement.Right.Expression }
        }
    }
    Process {
        [ScriptBlock]$Predicate = {
            Param ([Ast]$Ast)
            if ($Ast -isnot [AssignmentStatementAst] -or $Ast.Operator -ne 'PlusEquals') { return $false }
            $VariableName = $Ast.Left.VariablePath.UserPath
            $OrNull = IsString $Ast.Right.Expression
            $BlockAst = $Ast.Parent
            if ($BlockAst -is [StatementBlockAst]) {
                if (GetEquals $VariableName $BlockAst) { return $false } # In scope assignment
                $StatementAst = $BlockAst.Parent
                if     ($StatementAst -is [ForStatementAst])     { return IsString -OrNull:$OrNull (GetEquals $VariableName $StatementAst) }
                elseif ($StatementAst -is [ForEachStatementAst]) { return IsString -OrNull:$OrNull (GetEquals $VariableName $StatementAst) }
                return $false
            }
            elseif ($BlockAst -is [NamedBlockAst]) {
                if (GetEquals $VariableName $BlockAst) { return $false } # In scope assignment
                $ScriptBlockAst = $BlockAst.Parent
                if ($ScriptBlockAst -isnot [ScriptBlockAst]) { return $false }
                $ScriptBlockExpressionAst = $ScriptBlockAst.Parent
                if ($ScriptBlockExpressionAst -isnot [ScriptBlockExpressionAst]) { return $false }
                $ExpressionAst = $ScriptBlockExpressionAst.Parent
                if ($ExpressionAst -is [InvokeMemberExpressionAst]) {
                    if ($ExpressionAst.Member.Value -ne 'foreach') { return $false }
                    if (GetEquals $VariableName $ExpressionAst) { return $false } # In scope assignment
                    $CommandExpressionAst = $ExpressionAst.Parent
                    if ($CommandExpressionAst -isnot [CommandExpressionAst]) { return $false }
                    $PipelineAst = $CommandExpressionAst.Parent
                    if ($PipelineAst -isnot [PipelineAst]) { return $false }
                    return IsString -OrNull:$OrNull (GetEquals $VariableName $PipelineAst)
                }
                elseif($ExpressionAst -is [CommandAst]) {
                    $CommandAst = $ScriptBlockExpressionAst.Parent
                    if ($CommandAst -isnot [CommandAst]) { return $false }
                    $Parameters = @{}
                    $CommandElement = $Null
                    $ParameterIndex = 0
                    foreach ($Element in $CommandAst.CommandElements) {
                        if (!$CommandElement -and $Element -is [StringConstantExpressionAst]) {
                            $CommandElement = $Element
                        }
                        elseif ($Element -is [ScriptBlockExpressionAst]) {
                            if ($ParameterName) { $Parameters[$ParameterName] = $Element }
                            else { $Parameters[$ParameterIndex++] = $Element }
                        }
                        $ParameterName = if ($Element -is [CommandParameterAst]) { $Element.ParameterName }
                    }
                    if ($CommandElement -in 'ForEach-Object', 'foreach', '%') {
                        if (!$Parameters.ContainsKey('Process')) {
                            if ($Parameters.ContainsKey('Begin') -and $Parameters.ContainsKey(1)) {
                                $Parameters['Begin']   = $Parameters[0]
                                $Parameters['Process'] = $Parameters[1]
                            }
                            elseif ($Parameters.ContainsKey(0)) {
                                $Parameters['Process'] = $Parameters[0]
                            }
                        }
                        if ($Parameters['Process'].Extent.StartOffset -eq $ScriptBlockAst.Extent.StartOffset) {
                            if ($Parameters.ContainsKey('Begin')) {
                                return IsString -OrNull:$OrNull (GetEquals $VariableName $Parameters['Begin'].ScriptBlock.EndBlock)
                            }
                            $PipelineAst = $ExpressionAst.Parent
                            if ($PipelineAst -isnot [PipelineAst]) { return $false }
                            return IsString -OrNull:$OrNull (GetEquals $VariableName $PipelineAst)
                        }
                    }
                }
            }
            return $false
        }

        $Violations = $ScriptBlockAst.FindAll($Predicate, $false)
        Foreach ($Violation in $Violations) {
            [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]@{
                Message              = "Avoid using the assignment by addition operator for building a string."
                Extent               = $Violation.Extent
                RuleName             = 'PSAvoidPlusEqualsToBuildStrings'
                Severity             = 'Warning'
                RuleSuppressionID    = $Violation.Left.VariablePath.UserPath
            }
        }
    }
}
Export-ModuleMember -Function Measure-*