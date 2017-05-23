#####
##
## Author: Robert Meany
## Modified: 1/30/2017
## Purpose: An instantiatable Logger class that allows you to define logging destinations and which levels to report to each destination.
##          The logger will not actually write the logs until the flush() method is called.
##
####

Class Logger {
    # Logger is an abstract class that is inherited by more specific types of loggers.

    [int]$logLevel
    static [int]$DEBUG = 5
    static [int]$INFO = 4
    static [int]$WARN = 3
    static [int]$ERROR = 2
    static [int]$FATAL = 1

    Logger() {
        $type = $This.GetType()
        if ($type -eq [Logger]) {
            throw("Class $type must be inherited.")
        }
    }
    flush() {
        # base flush() does not do anything.  Loggers that inherit this class may override,
        # to send gathered (cached) messages.
    }
    log([int]$level, [string]$msg) {
        # Override this method to perform specific logging action.
    }
}

Class FileLogger : Logger {
    [string]$logFilePath

    log([int]$level, [string]$msg) {
        if ($level -le $This.logLevel) {
            if ($This.logFilePath) {
                [string]$lvltxt = ""
                switch ($level) {
                    1 {$lvltxt = "FATAL"}
                    2 {$lvltxt = "ERROR"}
                    3 {$lvltxt = "WARN"}
                    4 {$lvltxt = "INFO"}
                    5 {$lvltxt = "DEBUG"}
                }
                $timestamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
                $line = "$timestamp`t$lvltxt`t$msg"
                Add-Content $This.logFilePath -Value $line
            }
            else {
                Throw "Log path not specified."
            }
        }
    }
}

Class ConsoleLogger : Logger {
    log([int]$level, [string]$msg) {
        if ($level -le $This.logLevel) {
            [string]$lvltxt = ""
            switch ($level) {
                1 {$lvltxt = "FATAL"}
                2 {$lvltxt = "ERROR"}
                3 {$lvltxt = "WARN"}
                4 {$lvltxt = "INFO"}
                5 {$lvltxt = "DEBUG"}
            }
            $timestamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
            $line = "$timestamp`t$lvltxt`t$msg"
            Write-Host $This.logFilePath -Value $line
        }
    }
}

Class SMTPLogger : Logger {
    [int]$autoFlushLogCount
    [string]$smtpServer
    [int]$smtpPort
    [string]$sender
    [string[]]$recipients
    [string]$subject
    hidden [System.Collections.ArrayList]$messages # Should call log method instead.  Method will check if autoflushlogcount has been reached and flush if necessary.
    hidden [System.Security.SecureString]$credentials

    SMTPLogger() {
        Throw "SMTPLogger must be created with required connection parameters."
    }

    SMTPLogger([string]$smtpServer, [int]$smtpPort=25, [string]$sender, [string[]]$recipients) {
        $This.smtpServer = $smtpServer
        $This.smtpPort = $smtpPort
        $This.sender = $sender
        $This.recipients = $recipients
        $This.autoFlushLogCount = 0
        $This.messages = [System.Collections.ArrayList]::new()
    }

    log([int]$level,[string]$msg) {
        if ($level -le $This.logLevel) {
            [string]$lvltxt = ""
            switch ($level) {
                1 {$lvltxt = "FATAL"}
                2 {$lvltxt = "ERROR"}
                3 {$lvltxt = "WARN"}
                4 {$lvltxt = "INFO"}
                5 {$lvltxt = "DEBUG"}
            }
            $timestamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
            $line = "$timestamp`t$lvltxt`t$msg"
            $This.messages.add($line)
            if ($This.messages.count -ge $This.autoFlushLogCount -and $This.autoFlushLogCount -ne 0) {$This.flush()}
        }
    }

    useCredentials([string]$username, [string]$password) {
        $pwd = $password | ConvertTo-SecureString -asPlainText -Force
        $This.credentials = [System.Management.Automation.PSCredential]::new($This.username,$pwd)
    }

    flush() {
        $msgs = [string[]]$This.messages.ToArray()

        # Don't send anything if there are no messages logged to send.
        if ($msgs.count -gt 0) {
            $message = $msgs -join "`n"
            if ($This.credentials) {
                Send-MailMessage -SmtpServer $This.smtpServer `
                                    -Port $This.smtpPort `
                                    -From $This.sender `
                                    -To $This.recipients `
                                    -Credential $This.credentials `
                                    -Subject $This.subject `
                                    -Body $message -ErrorAction Stop
                $This.messages.Clear()
            }
            else {
                Send-MailMessage -SmtpServer $This.smtpServer `
                                    -Port $This.smtpPort `
                                    -From $This.sender `
                                    -To $This.recipients `
                                    -Subject $This.subject `
                                    -Body $message -ErrorAction Stop
                $This.messages.Clear()
            }
        }
    }
}

Class LogManager {
    hidden [System.Collections.ArrayList]$loggers

    LogManager() {
        $This.loggers = [System.Collections.ArrayList]::new()
    }

    addLogger($logger) {
        $This.loggers.add($logger)
    }

    log([int]$level,[string]$message) {
        ForEach ($logger in $This.loggers) {
            $logger.log($level, $message)
        }
    }

    flush() {
        # Flush (send) all messages for all attached loggers that support it.
        ForEach ($logger in $This.loggers) {
            $logger.flush()
        }
    }
}

# Seperate simple writelog function for backwards compatibility
Function WriteLog {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$False)][ValidateSet("INFO","WARN","ERROR","FATAL","DEBUG")][String]$Level = "INFO",
        [Parameter(Mandatory=$True)][string]$Message,
        [Parameter(Mandatory=$False)][string]$logfile
    )

    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $Line = "$Stamp $Level $Message"
    If($logfile) {
        Add-Content $logfile -Value $Line
    }
    Else {
        Write-Output $Line
    }
}

# Implement your module commands in this script.
function New-LogManager {
    [CmdletBinding()]
    param (

    )

    begin {
    }

    process {
        $lm =  [LogManager]::new();
        write-output $lm
    }

    end {
    }
}

<#
.SYNOPSIS
Adds a new file logger to the File Manager

.DESCRIPTION
Creats a File Logger that is managed by the Log manager.

.PARAMETER Path
Path of the file to write the log

.PARAMETER logLevel
The level threshold the logger will be triggered by

.PARAMETER LogManager
The Log Manager object for managing all loggers.

.EXAMPLE
$LogManager = New-LogManager
New-FileLogger -Path "C:\Logfile.Log" -LogLevel "Info" -LogManager $LogManager
New-Log -LogManager $Logmanager -Loglevel "Info" -Message "Hello World!"

.NOTES
Work in Progress
#>
function New-FileLogger {
    [CmdletBinding()]
    param (
        # Specifies a path to one or more locations.
        [Parameter(Mandatory=$true,
                   Position=0,
                   ParameterSetName="Path",
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   HelpMessage="Path to one or more locations.")]
        [Alias("PSPath")]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Path,

        # Sets the log level threashold collected by this logger
        [Parameter(Mandatory=$false,
                   Position=1,
                   ValueFromPipeline=$false,
                   ValueFromPipelineByPropertyName=$true,
                   HelpMessage="Set Logging level. Valid Levels are FATAL,ERROR,WARN,INFO,DEBUG")]
        [string]
        $logLevel,

        # The Manager of this logger.
        [Parameter(Mandatory=$true,
                   Position=2,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   HelpMessage="Specifies the manager of this logger.")]
        [LogManager]
        $LogManager
    )

    begin {
    }

    process {
        $fl = [FileLogger]::new()

        if($loglevel -ne $null){
            $fl.logLevel = [Logger]::$loglevel
        }
        $fl.logFilePath = $Path
        $LogManager.addLogger($fl)
    }

    end {
    }
}

function New-SMTPLogger {
    [CmdletBinding()]
    param (

    )

    begin {
    }

    process {
    }

    end {
    }
}

function New-Log {
    [CmdletBinding()]
    param (
        # Specify the LogManager that will process this log.
        [Parameter(Mandatory=$true,
                   Position=0,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   HelpMessage="Specify the logManager to handle this log.")]
        [LogManager]
        $LogManager,
        # What your log message says
        [Parameter(Mandatory=$true,
                   Position=1,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   HelpMessage="Specify the message of this log")]
        [String[]]
        $Message,
        # The level of the log message
        [Parameter(Mandatory=$false,
                   Position=2,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   HelpMessage="Specify the alert level of this log.")]
        [String]
        $LogLevel = "INFO"
    )

    begin {
    }

    process {
        $LogManager.log([Logger]::$LogLevel,$Message)
    }

    end {
    }
}

function Invoke-LogManagerFlush {
    [CmdletBinding()]
    param (
        # Specify the LogManager that will process this log.
        [Parameter(Mandatory=$true,
                   Position=0,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   HelpMessage="Specify the logManager to handle this log.")]
        [LogManager]
        $LogManager
    )

    begin {
    }

    process {
        $LogManager.flush()
    }

    end {
    }
}

Export-ModuleMember -Function *-*
# Export only the functions using PowerShell standard verb-noun naming.
# Be sure to list each exported functions in the FunctionsToExport field of the module manifest file.
# This improves performance of command discovery in PowerShell.
