#Requires -RunAsAdministrator
<#  
.SYNOPSIS  
    Creates an MSIX app attach (vhdx) container for a given folder of .msix files
.DESCRIPTION  
code borrowed from fberson https://github.com/fberson/wvd/blob/master/MSIX%20app%20attach/Create-MSIXAppAttachContainer.ps1 and edited for newer version of msixmgr.exe
some code found some writen :)

    This scripts creates an MSIX app attach (vhdx) container for a given folder:
    - Creating the MSIX parent folder
    - Extracting the MSIX into the parent folder

.NOTES  
    File Name  : create-MSIXAppAttachContainer.ps1
    Author     : Torbjorn Karlsson
    Version    : v0.0.2
.EXAMPLE
    .\create-MSIXAppAttachContainer.ps1 -MSIXSourceLocation C:\install\MSIXpackages
.DISCLAIMER
    Use at your own risk. This scripts are provided AS IS without warranty of any kind. The author further disclaims all implied
    warranties including, without limitation, any implied warranties of merchantability or of fitness for a particular purpose. The entire risk
    arising out of the use or performance of the scripts and documentation remains with you. In no event shall the author, or anyone else involved
    in the creation, production, or delivery of the scripts be liable for any damages whatsoever (including, without limitation, damages for loss
    of business profits, business interruption, loss of business information, or other pecuniary loss) arising out of the use of or inability
    to use the this script.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "sökväg till mapp med .MSIX filer")][ValidateNotNullOrEmpty()]
    [string]$MSIXSourceLocation
)

$MSIXappattachContainerExtension = "vhdx"
$MsixmgrFolder = "$MSIXSourceLocation\msixmgr"
$MsixmgrZip = "$MSIXSourceLocation\msixmgr.zip"
$msixmgrURL = "https://aka.ms/msixmgr"
If ([Environment]::Is64BitOperatingSystem) {
    $MsixmgrExe = "$MsixmgrFolder\x64\msixmgr.exe"
}
else {
    $MsixmgrExe = "$MsixmgrFolder\x86\msixmgr.exe"

}
If ( - !(Test-Path $MsixmgrExe)) {
    Write-Host "downloading MSIXMgr needed to complete the transformation"
    Invoke-WebRequest -Uri $msixmgrURL -OutFile $MsixmgrZip -PassThru -UseBasicParsing

    If ((Test-Path $MsixmgrZip)) {
        Expand-Archive -Path $MsixmgrZip -DestinationPath $MsixmgrFolder
        If ( - !(Test-Path $MsixmgrExe)) {
            $ErrorMessage = $_.Exception.Message
            Return
        }
    }
    else {
        $ErrorMessage = $_.Exception.Message
        Return
    }
}
#CLS

$files = Get-ChildItem -Path $MSIXSourceLocation -Recurse -Include "*.msix"
foreach ($file in $files) {
    $Starttime = get-date
    $MSIXappattachContainerLabel = $file.name -replace '.msix', ''
    $MSIXappattachContainerRootFolder = $MSIXappattachContainerLabel
    #Create MSIX Root Folder 
    New-Item -Path ($MSIXSourceLocation + "\" + $MSIXappattachContainerRootFolder) -ItemType Directory
    $NeededSize = (((Get-ChildItem $file.FullName -Recurse | measure Length -sum).sum) * 2)


    If ($NeededSize -lt 6815744) {
        $NeededSize = 6.5MB
    }
    else {
        $NeededSize = ([System.Math]::ceiling($NeededSize / 1MB)) * 1024 * 1024
    }
    $MSIXappattachContainerSizeMb = ([math]::round($NeededSize / 1mb)) + 21
    $MisxmgrArgument = "-Unpack -packagePath ""$($file.fullname)"" -destination ""$MSIXSourceLocation\$MSIXappattachContainerRootFolder\$MSIXappattachContainerLabel.$MSIXappattachContainerExtension"" -vhdSize $MSIXappattachContainerSizeMb -applyacls -create -filetype $MSIXappattachContainerExtension -rootDirectory apps"
    #Extract the MSIX into the app attach container (vhdx)
    $result = Start-Process -FilePath $MsixmgrExe -ArgumentList ($MisxmgrArgument) -Wait -PassThru -WindowStyle Hidden
    IF ($Result.ExitCode -ne 0) {
        write-host "Failed to extract MSIX using: $MsixmgrExe $MisxmgrArgument" -ForegroundColor Yellow
        Write-Host "Try cleaning up $env:SystemRoot\temp"
        return
    }
    else {
        #Grab the File info needed for the Staging part of MSIX app attach
        Write-Host "Completed transforming:"$MSIXappattachContainerLabel -ForegroundColor green
        Write-Host "Package location:"$MSIXSourceLocation\$MSIXappattachContainerRootFolder\$MSIXappattachContainerLabel.$MSIXappattachContainerExtension""
        Write-Host "Total transformation time:"((get-date) - $Starttime).Minutes "Minute(s) and" ((get-date) - $Starttime).seconds "Seconds."
    }
}