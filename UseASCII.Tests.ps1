#Requires -Modules @{ModuleName="Pester"; ModuleVersion="5.0.0"}

Describe 'UseASCII' {

    BeforeAll {
        $TemporaryFile = [System.IO.Path]::ChangeExtension((New-TemporaryFile), '.ps1')
    }

    Context 'Positives' {

        It 'Smart characters' {
            $Result = Invoke-ScriptAnalyzer -CustomRulePath .\UseASCII.psm1 -ScriptDefinition { Write-Host 'coöperate' }.ToString()
            $Result.RuleName | Should -Be 'PSUseASCII'
            $Result.Severity | Should -Be 'Information'
        }

        It 'Fix' {
            Set-Content -LiteralPath $TemporaryFile -Encoding utf8 -NoNewline -Value {
                <#
                    .SYNOPSIS
                    Use ASCII test
                    .DESCRIPTION
                    The main use of diacritics in Latin script is to change the sound-values of the letters to which they are added.
                    Historically, English has used the diaeresis diacritic to indicate the correct pronunciation of ambiguous words,
                    such as "coöperate", without which the <oo> letter sequence could be misinterpreted to be pronounced
                #>

                # [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseAscii', 'coöperate')]
                Param()

                Write-Host “test” –ForegroundColor ‘Red’ -BackgroundColor ‘Green’
                Write-Host 'No-break space'
            }.ToString()
            Invoke-ScriptAnalyzer -Fix -CustomRulePath .\UseASCII.psm1 -Path $TemporaryFile
            Get-Content -Raw -Literal $TemporaryFile | Should -be {
                <#
                    .SYNOPSIS
                    Use ASCII test
                    .DESCRIPTION
                    The main use of diacritics in Latin script is to change the sound-values of the letters to which they are added.
                    Historically, English has used the diaeresis diacritic to indicate the correct pronunciation of ambiguous words,
                    such as "cooperate", without which the <oo> letter sequence could be misinterpreted to be pronounced
                #>

                # [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseAscii', 'cooperate')]
                Param()

                Write-Host "test" -ForegroundColor 'Red' -BackgroundColor 'Green'
                Write-Host 'No-break space'
            }.ToString()
        }

        It 'Suppress' {
            Set-Content -LiteralPath $TemporaryFile -Encoding utf8 -NoNewline -Value {
                <#
                    .SYNOPSIS
                    Use ASCII test
                    .DESCRIPTION
                    The main use of diacritics in Latin script is to change the sound-values of the letters to which they are added.
                    Historically, English has used the diaeresis diacritic to indicate the correct pronunciation of ambiguous words,
                    such as "coöperate", without which the <oo> letter sequence could be misinterpreted to be pronounced
                #>

                [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseAscii', 'coöperate')]
                Param()

                Write-Host “test” –ForegroundColor ‘Red’ -BackgroundColor ‘Green’
                Write-Host 'No-break space'
            }.ToString()
            Invoke-ScriptAnalyzer -Fix -CustomRulePath .\UseASCII.psm1 -Path $TemporaryFile -ErrorAction SilentlyContinue
            Get-Content -Raw -Literal $TemporaryFile | Should -be {
                <#
                    .SYNOPSIS
                    Use ASCII test
                    .DESCRIPTION
                    The main use of diacritics in Latin script is to change the sound-values of the letters to which they are added.
                    Historically, English has used the diaeresis diacritic to indicate the correct pronunciation of ambiguous words,
                    such as "coöperate", without which the <oo> letter sequence could be misinterpreted to be pronounced
                #>

                [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseAscii', 'coöperate')]
                Param()

                Write-Host "test" -ForegroundColor 'Red' -BackgroundColor 'Green'
                Write-Host 'No-break space'
            }.ToString()
        }
   }

    AfterAll {
        # if (Test-Path -LiteralPath $TemporaryFile) { Remove-Item -LiteralPath $TemporaryFile }
    }
}