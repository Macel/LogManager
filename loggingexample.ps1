<#
    Spent the better part of the evening adding CMDLETs to your module. Right now only
    the FileLogger class, the LogManager class, the AddLogger method, the Log Method,
    and the Flush method are represented.

    I've recreated part of your example using the cmdlets I built so you ge tan idea
    of how it all works.

    Each Logger Type could be its own cmdlet:
        New-FileLogger
        New-SMTPLogger
        New-ConsoleLogger
        etc.
#>

# using module "\\naugatuck\scripts\public\Logging.psm1"
Import-Module Logging

Get-Module "Logging"

""

#Get-Command -Module Logging
# $lm = [LogManager]::new()
$lm = New-LogManager

# $fl = [FileLogger]::new()
# $fl.logLevel = [Logger]::DEBUG
# $fl.logFilePath = "$env:SystemDrive\Users\$env:USERNAME\log.log"
# $lm.addLogger($fl)

# the New-FileLogger creates a new file logger object and adds it to your logmanager in one command
$logPath = "$env:SystemDrive\Users\$env:USERNAME\log.log"
New-FileLogger -LogManager $lm -LogLevel "INFO" -Path $logPath

#$lm.log([Logger]::INFO,"This is an info-level message")
#$lm.log([Logger]::ERROR,"This is an error-level message")
New-Log -LogManager $lm -LogLevel "INFO" -Message "This is an info-level message"
New-Log -LogManager $lm -Message "This should have a default value of Info"
$lm | New-Log -Loglevel "INFO" -message "This is a message from the pipeline, with Info level logging"


#$lm.flush()
Invoke-LogManagerFlush -LogManager $lm #currently does nothing since File Logger doesn't need to be flushed.


""

Get-Content $logPath