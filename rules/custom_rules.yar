/*
 * CyberThreatGotchi — custom YARA rules
 * Deploy to BPI-R3 Mini via scripts/install.sh
 */

rule CTG_Suspicious_ELF {
    meta:
        description = "Suspicious ELF header in transit payload"
        severity = "high"
        author = "Hacker Planet LLC"
    strings:
        $elf = { 7F 45 4C 46 }
        $exec = "exec" nocase
    condition:
        $elf at 0 or ($elf and $exec)
}

rule CTG_PowerShell_Encoded {
    meta:
        description = "Encoded PowerShell command pattern"
        severity = "high"
    strings:
        $a = "-EncodedCommand" nocase
        $b = "FromBase64String" nocase
    condition:
        any of them
}

rule CTG_Webshell_PHP {
    meta:
        description = "Common PHP webshell indicators"
        severity = "critical"
    strings:
        $p1 = "eval($_POST" nocase
        $p2 = "system($_GET" nocase
        $p3 = "passthru(" nocase
    condition:
        any of them
}

rule CTG_Mass_Business_Cat_Phish {
    meta:
        description = "Phishing lure keywords (mass + business targeting)"
        severity = "medium"
    strings:
        $urgent = "urgent wire transfer" nocase
        $ceo = "CEO request" nocase
        $invoice = "invoice attached" nocase
        $payroll = "payroll update" nocase
    condition:
        2 of them
}
