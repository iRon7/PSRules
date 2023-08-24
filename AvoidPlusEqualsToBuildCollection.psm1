#Requires -Version 3.0

using namespace System.Management.Automation.Language

function Measure-AvoidPlusEqualsToBuildCollection {
<#
    .SYNOPSIS
    Avoid using the Assignment by Addition Operator to build a collection
    .DESCRIPTION
    Array addition is inefficient because arrays have a fixed size. Each addition to the array
    creates a new array big enough to hold all elements of both the left and right operands.
    The elements of both operands are copied into the new array. For small collections, this
    overhead may not matter. Performance can suffer for large collections.
    See also: https://learn.microsoft.com/powershell/scripting/dev-cross-plat/performance/script-authoring-considerations
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
    Begin {
        function IsAssigned ([String]$VariableName, [Ast]$Statement, [Switch]$Empty) {
            If ($Statement -is [NamedBlockAst] -or $Statement -is [StatementBlockAst]) {
                $Container = $Statement
                $Index = $Container.Statements.Count
            }
            else {
                $Container = $Statement.Parent
                if ($Container -isnot [NamedBlockAst]) { Return $false }
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
            if ($Index -lt 0) { return $false }
            if ($Empty) {
                return (
                    $EqualsStatement.Right.Expression -is [ArrayExpressionAst] -and
                    !$EqualsStatement.Right.Expression.SubExpression.Extent.Text
                )
            } else { return $true }
        }
    }
    Process {
        [ScriptBlock]$Predicate = {
            Param ([Ast]$Ast)
            if ($Ast -isnot [AssignmentStatementAst] -or $Ast.Operator -ne 'PlusEquals') { return $false }
            $VariableName = $Ast.Left.VariablePath.UserPath
            $BlockAst = $Ast.Parent
            if ($BlockAst -is [StatementBlockAst]) {
                if (IsAssigned -Empty $VariableName $BlockAst) { return $false } # Controlled
                $StatementAst = $BlockAst.Parent
                if     ($StatementAst -is [ForStatementAst])     { return (IsAssigned -Empty $VariableName $StatementAst) }
                elseif ($StatementAst -is [ForEachStatementAst]) { return (IsAssigned -Empty $VariableName $StatementAst) }
                return $false
            }
            elseif ($BlockAst -is [NamedBlockAst]) {
                if (IsAssigned -Empty $VariableName $BlockAst) { return $false } # Controlled
                $ScriptBlockAst = $BlockAst.Parent
                if ($ScriptBlockAst -isnot [ScriptBlockAst]) { Return $false }
                $ScriptBlockExpressionAst = $ScriptBlockAst.Parent
                if ($ScriptBlockExpressionAst -isnot [ScriptBlockExpressionAst]) { return $false }
                $ExpressionAst = $ScriptBlockExpressionAst.Parent
                if ($ExpressionAst -is [InvokeMemberExpressionAst]) {
                    if ($ExpressionAst.Member.Value -ne 'foreach') { return $false }
                    if (IsAssigned -Empty $VariableName $ExpressionAst) { return $false } # Controlled
                    $CommandExpressionAst = $ExpressionAst.Parent
                    if ($CommandExpressionAst -isnot [CommandExpressionAst]) { return $false }
                    $PipelineAst = $CommandExpressionAst.Parent
                    if ($PipelineAst -isnot [PipelineAst]) { return $false }
                    return (IsAssigned -Empty $VariableName $PipelineAst)
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
                                IsAssigned -Empty $VariableName $Parameters['Begin'].ScriptBlock.EndBlock
                            }
                            $PipelineAst = $ExpressionAst.Parent
                            if ($PipelineAst -isnot [PipelineAst]) { return $false }
                            return (IsAssigned -Empty $VariableName $PipelineAst)
                        }
                    }
                }
            }
            return $false
        }

        $Violations = $ScriptBlockAst.FindAll($Predicate, $false)
        Foreach ($Violation in $Violations) {
            [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]@{
                Message              = "Avoid using the assignment by addition operator for building a collection."
                Extent               = $Violation.Extent
                RuleName             = 'AvoidPlusEqualsToBuildCollection'
                Severity             = 'Warning'
                RuleSuppressionID    = $Violation.Left.VariablePath.UserPath
            }
        }
    }
}
Export-ModuleMember -Function Measure-*
