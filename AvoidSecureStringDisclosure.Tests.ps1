#Requires -Modules @{ModuleName="Pester"; ModuleVersion="5.0.0"}

Describe 'AvoidSecureStringDisclosure' {

    Context 'Positives' {
        It 'ConvertFrom-SecureString' {
            $Expression = {
                $SecureString = ConvertTo-SecureString 'P@ssW0rd' -AsPlainText
                $Null = $SecureString | ConvertFrom-SecureString -AsPlainText
            }.ToString()
            $Results = Invoke-ScriptAnalyzer -ScriptDefinition $Expression -CustomRulePath .\AvoidSecureStringDisclosure.psm1
            $Results | Should -not -BeNullOrEmpty
            $Results.RuleName | Should -Be 'PSAvoidSecureStringDisclosure'
            $Results.RuleSuppressionID | Should -Be 'ConvertFrom-SecureString'
        }
        It 'SecureStringToBSTR' {
            $Expression = {
                $SecureString = ConvertTo-SecureString 'P@ssW0rd' -AsPlainText
                $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
                $Null = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
                [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
            }.ToString()
            $Results = Invoke-ScriptAnalyzer -ScriptDefinition $Expression -CustomRulePath .\AvoidSecureStringDisclosure.psm1
            $Results | Should -not -BeNullOrEmpty
            $Results.RuleName | Should -Be 'PSAvoidSecureStringDisclosure'
            $Results.RuleSuppressionID | Should -Be 'SecureStringToBSTR'
        }
        It 'GetNetworkCredential' {
            $Expression = {
                $SecureString = ConvertTo-SecureString 'P@ssW0rd' -AsPlainText
                $Null = (New-Object PSCredential 0, $SecureString).GetNetworkCredential().Password
            }.ToString()
            $Results = Invoke-ScriptAnalyzer -ScriptDefinition $Expression -CustomRulePath .\AvoidSecureStringDisclosure.psm1
            $Results | Should -not -BeNullOrEmpty
            $Results.RuleName | Should -Be 'PSAvoidSecureStringDisclosure'
            $Results.RuleSuppressionID | Should -Be 'GetNetworkCredential'
        }
    }
}