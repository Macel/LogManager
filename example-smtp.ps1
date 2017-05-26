# Send logs via Email.

import-module Logging

$lm = New-Logmanager

New-SMTPLogger -SMTPServer "smtp.gmail.com" `
                -Port 587 `
                -LogManager $lm `
                -LogLevel "INFO" `
                -From "alerts@VandelayIndustries.com" `
                -To "art.vandelay@VandelayIndustries.org" `
                -Subject "Imports/Exports Log $(get-date)" `
                -Credentials "alerts@VandelayIndustries.com" `
                -usessl

New-Log -LogManager $lm -Message "hello World 1" -LogLevel "INFO"
New-Log -LogManager $lm -Message "hello World 2" -LogLevel "INFO"
New-Log -LogManager $lm -Message "hello World 3" -LogLevel "INFO"

Invoke-LogManagerFlush -LogManager $lm