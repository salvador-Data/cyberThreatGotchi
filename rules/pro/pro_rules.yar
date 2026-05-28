/*
 * CyberThreatGotchi PRO — supplemental YARA rules
 * Requires CTG_PRO_API_KEY on feed endpoint
 */

rule CTG_PRO_Ransomware_Note {
    meta:
        description = "Ransom note keywords in payload"
        severity = "critical"
        tier = "pro"
    strings:
        $a = "your files have been encrypted" nocase
        $b = ".onion" nocase
        $c = "bitcoin wallet" nocase
    condition:
        2 of them
}

rule CTG_PRO_Lateral_SMB {
    meta:
        description = "Lateral movement over SMB patterns"
        severity = "high"
        tier = "pro"
    strings:
        $a = "\\\\ADMIN$" nocase
        $b = "psexec" nocase
        $c = "wmic /node:" nocase
    condition:
        any of them
}
