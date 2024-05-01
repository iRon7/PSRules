#Requires -Version 3.0

function Measure-UseASCII {
<#
    .SYNOPSIS
    Use UTF-8 Characters
    .DESCRIPTION
    Validates if only ASCII characters are used and reveal the position of any violation.
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
        function GetNonASCIIPositions ([String]$Text) {
            $LF  = [Char]0x0A
            $DEL = [Char]0x7F
            $LineNumber = 1; $ColumnNumber = 1
            for ($Offset = 0; $Offset -lt $Text.Length; $Offset++) {
                $Character = $Text[$Offset]
                if ($Character -eq $Lf) {
                    $LineNumber++
                    $ColumnNumber = 0
                }
                else {
                    $ColumnNumber++
                    if ($Character -gt $Del) {
                        [PSCustomObject]@{
                            Character    = $Character
                            Offset       = $Offset
                            LineNumber   = $LineNumber
                            ColumnNumber = $ColumnNumber
                        }
                    }
                }
            }
        }

        function CharToHex([Char]$Char) {
            ([Int][Char]$Char).ToString('x4')
        }
        function SuggestedASCII([Char]$Char) {
            switch ([Int]$Char) {
                0x00A0 { ' ' }
                0x1806 { '-' }
                0x2010 { '-' }
                0x2011 { '-' }
                0x2012 { '-' }
                0x2013 { '-' }
                0x2014 { '-' }
                0x2015 { '-' }
                0x2016 { '-' }
                0x2212 { '-' }
                0x2018 { "'" }
                0x2019 { "'" }
                0x201A { "'" }
                0x201B { "'" }
                0x201C { '"' }
                0x201D { '"' }
                0x201E { '"' }
                0x201F { '"' }
                Default {
                    $ASCII = $Char.ToString().Normalize([System.text.NormalizationForm]::FormD)[0]
                    if ($ASCII -le 0x7F) { $ASCII } else { '_' }
                }

            }
        }
    }

    Process {
        # As the AST parser, tokenize doesn't capture (smart) quotes
        # $Tokens = [System.Management.Automation.PSParser]::Tokenize($ScriptBlockAst.Extent.Text, [ref]$null)
        # $Violations = $Tokens.where{ $_.Content -cMatch '[\u0100-\uFFFF]' }
        $Violations = GetNonASCIIPositions $ScriptBlockAst.Extent.Text
        [Collections.Generic.List[Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]]@(
            Foreach ($Violation in $Violations) {
                $Text = $ScriptBlockAst.Extent.Text
                For ($i = $Violation.Offset - 1; $i -ge 0; $i--) { if ($Text[$i] -NotMatch '\w') { break } }
                $Start = $i + 1
                For ($i = $Violation.Offset + 1; $i -lt $Text.Length; $i++) { if ($Text[$i] -NotMatch '\w') { break } }
                $Length = $i - $Start
                $Word = $Text.SubString($Start, $Length)

                $StartPosition = [System.Management.Automation.Language.ScriptPosition]::new(
                    $Null,
                    $Violation.LineNumber,
                    $Violation.ColumnNumber,
                    $ScriptBlockAst.Extent.Text
                )
                $EndPosition = [System.Management.Automation.Language.ScriptPosition]::new(
                    $Null,
                    $Violation.LineNumber,
                    ($Violation.ColumnNumber + 1),
                    $ScriptBlockAst.Extent.Text
                )
                $Extent = [System.Management.Automation.Language.ScriptExtent]::new($StartPosition, $EndPosition)
                $Character = $Violation.Character
                $UniCode   = "U+$(CharToHex $Character)"
                $SuggestedASCII = SuggestedASCII $Character
                $AscCode   = "U+$(CharToHex $SuggestedASCII)"
                [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]@{
                    Message              = "Non-ASCII character $UniCode found in: $Word"
                    Extent               = $Extent
                    RuleName             = 'PSUseASCII'
                    Severity             = 'Information'
                    RuleSuppressionID    = $Word
                    SuggestedCorrections = [System.Collections.ObjectModel.Collection[Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.CorrectionExtent]](
                        [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.CorrectionExtent]::New(
                            $Violation.LineNumber,
                            $Violation.LineNumber,
                            $Violation.ColumnNumber,
                            ($Violation.ColumnNumber + 1),
                            "$SuggestedASCII",
                            "Replace '$Character' ($UniCode) with '$SuggestedASCII' ($AscCode)"
                        )
                    )
                }
            }
        )
    }
}
Export-ModuleMember -Function Measure-*
