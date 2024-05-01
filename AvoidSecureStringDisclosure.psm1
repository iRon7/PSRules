#Requires -Version 3.0

using namespace System.Management.Automation.Language

function Measure-AvoidSecureStringDisclosure {
<#
    .SYNOPSIS
    Avoid SecureString disclosure.

    .DESCRIPTION
    For better security, it should be avoided to retrieve a PlainText passwords from a SecureString
    as it might leave memory trials (or even logging trails).

    The general approach of dealing with credentials is to avoid them and instead rely on other means
    to authenticate, such as certificates or Windows authentication.

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
                $Ast -is [CommandAst] -and
                $Ast.CommandElements[0].Value -eq 'ConvertFrom-SecureString' -and
                $Ast.CommandElements.where{ $_ -is [CommandParameterAst] -and $_.ParameterName -eq 'AsPlainText' }
            ) -or
            (
                $Ast -is [InvokeMemberExpressionAst] -and
                $Ast.Member.Value -eq 'SecureStringToBSTR'
            ) -or
            (
                $Ast -is [MemberExpressionAst] -and
                $Ast.Expression -is [InvokeMemberExpressionAst] -and
                $Ast.Member.Value -eq 'Password' -and
                $Ast.Expression.Member.Value -eq 'GetNetworkCredential'
            )
        }
        $Violations = $ScriptBlockAst.FindAll($Predicate, $False)
        Foreach ($Violation in $Violations) {
            $Extent = $Violation.Extent
            [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]@{
                Message              = "Avoid SecureString disclosure: $Extent"
                Extent               = $Extent
                RuleName             = 'PSAvoidSecureStringDisclosure'
                Severity             = 'Warning'
                RuleSuppressionID    = [Regex]::Match($Extent.Text, 'ConvertFrom-SecureString|SecureStringToBSTR|GetNetworkCredential').Value
            }
        }
    }
}
Export-ModuleMember -Function Measure-*
