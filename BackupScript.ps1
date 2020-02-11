﻿########################################################
# Forked from: http://www.techguy.at/tag/backupscript/
# Name: BackupScript.ps1                              
# Creator: Chase Jacobs
# CreationDate: 2020.02.11                              
# LastModified: 2020.02.11                               
# Version: 1
########################################################

#Description: Copies the Bakupdirs to the Destination
#You can configure more than one Backupdirs, every Dir
#wil be copied to the Destination. A Progress Bar
#is showing the Status of copied MB to the total MB
#Only Change Variables in Variables Section
#Change LoggingLevel to 3 an get more output in Powershell Windows



param (
[string]$source = "C:\Users\chase\Google Drive\Books",
[string]$destination = "C:\Users\chase\Downloads\Backup",
[string]$stage = "C:\Users\chase\Downloads\Stage"
)

#Variables, only Change here
$Destination=$destination #Copy the Files to this Location
#$Destination="C:\Users\seimi\Downloads"
$Staging=$stage
$ClearStaging=$true # When $true, Staging Dir will be cleared
$Versions="5" #How many of the last Backups you want to keep
$BackupDirs=$source #What Folders you want to backup

$ExcludeDirs="" #This list of Directories will not be copied

$LogName="Log.txt" #Log Name
$LoggingLevel="3" #LoggingLevel only for Output in Powershell Window, 1=smart, 3=Heavy
$Zip=$true #Zip the Backup Destination
$RemoveBackupDestination=$true #Remove copied files after Zip, only if $Zip is true
$UseStaging=$true #only if you use ZIP, than we copy file to Staging, zip it and copy the ZIP to destination, like Staging, and to save NetworkBandwith

$ErrorActionPreference = "Stop"

#Send Mail Settings
$SendEmail = $false                    # = $true if you want to enable send report to e-mail (SMTP send)
$EmailTo   = 'test@domain.com'              #user@domain.something (for multiple users use "User01 &lt;user01@example.com&gt;" ,"User02 &lt;user02@example.com&gt;" )
$EmailFrom = 'from@domain.com'   #matthew@domain 
$EmailSMTP = 'smtp.domain.com' #smtp server adress, DNS hostname.


#STOP-no changes from here
#STOP-no changes from here
#Settings - do not change anything from here

$ExcludeString=""
#[string[]]$excludedArray = $ExcludeDirs -split "," 
foreach ($Entry in $ExcludeDirs)
{
    $Temp="^"+$Entry.Replace("\","\\")
    $ExcludeString+=$Temp+"|"
}
$ExcludeString=$ExcludeString.Substring(0,$ExcludeString.Length-1)
#$ExcludeString
[RegEx]$exclude = $ExcludeString

if ($UseStaging -and $Zip)
{
    #Logging "INFO" "Use Temp Backup Dir"
    $Backupdir=$Staging +"\Backup-"+ (Get-Date -format yyyy-MM-dd)+"-"+(Get-Random -Maximum 100000)+"\"
}
else
{
    #Logging "INFO" "Use orig Backup Dir"
    $Backupdir=$Destination +"\Backup-"+ (Get-Date -format yyyy-MM-dd)+"-"+(Get-Random -Maximum 100000)+"\"
}



#$BackupdirTemp=$Temp +"\Backup-"+ (Get-Date -format yyyy-MM-dd)+"-"+(Get-Random -Maximum 100000)+"\"
$Log=$Backupdir+$LogName
$Log
$Items=0
$Count=0
$ErrorCount=0
$StartDate=Get-Date #-format dd.MM.yyyy-HH:mm:ss

#FUNCTION
#Logging
Function Logging ($State, $Message) {
    $Datum=Get-Date -format dd.MM.yyyy-HH:mm:ss

    if (!(Test-Path -Path $Log)) {
        New-Item -Path $Log -ItemType File | Out-Null
    }
    $Text="$Datum - $State"+":"+" $Message"

    if ($LoggingLevel -eq "1" -and $Message -notmatch "was copied") {Write-Host $Text}
    elseif ($LoggingLevel -eq "3") {Write-Host $Text}
   
    add-Content -Path $Log -Value $Text
    
}


#Create Backupdir
Function Create-Backupdir {
    New-Item -Path $Backupdir -ItemType Directory | Out-Null
    sleep -Seconds 5
    Logging "INFO" "Create Backupdir $Backupdir"
}

#Delete Backupdir
Function Delete-Backupdir {
    $Folder=Get-ChildItem $Destination | where {$_.Attributes -eq "Directory"} | Sort-Object -Property CreationTime -Descending:$false | Select-Object -First 1

    Logging "INFO" "Remove Dir: $Folder"
    
    $Folder.FullName | Remove-Item -Recurse -Force 
}


#Delete Zip
Function Delete-Zip {
    $Zip=Get-ChildItem $Destination | where {$_.Attributes -eq "Archive" -and $_.Extension -eq ".zip"} |  Sort-Object -Property CreationTime -Descending:$false |  Select-Object -First 1

    Logging "INFO" "Remove Zip: $Zip"
    
    $Zip.FullName | Remove-Item -Recurse -Force 
}

#Check if Backupdirs and Destination is available
function Check-Dir {
    Logging "INFO" "Check if BackupDir and Destination exists"
    if (!(Test-Path $BackupDirs)) {
        return $false
        Logging "Error" "$BackupDirs does not exist"
    }
    if (!(Test-Path $Destination)) {
        return $false
        Logging "Error" "$Destination does not exist"
    }
    if ($UseStaging) {
		if (!(Test-Path $Staging)) {
			return $false
			Logging "Error" "$Staging does not exist"
		}
	}
}

#Save all the Files
Function Make-Backup {
    Logging "INFO" "Started the Backup"
    $Files=@()
    $SumMB=0
    $SumItems=0
    $SumCount=0
    $colItems=0
    Logging "INFO" "Count all files and create the Top Level Directories"

    foreach ($Backup in $BackupDirs) {
        $colItems = (Get-ChildItem $Backup -recurse | Where-Object {$_.mode -notmatch "h"} | Measure-Object -property length -sum) 
        $Items=0
        $FilesCount += Get-ChildItem $Backup -Recurse | Where-Object {$_.mode -notmatch "h"}  
        Copy-Item -Path $Backup -Destination $Backupdir -Force -ErrorAction SilentlyContinue
        $SumMB+=$colItems.Sum.ToString()
        $SumItems+=$colItems.Count
    }

    $TotalMB="{0:N2}" -f ($SumMB / 1MB) + " MB of Files"
    Logging "INFO" "There are $SumItems Files with  $TotalMB to copy"

    foreach ($Backup in $BackupDirs) {
        $Index=$Backup.LastIndexOf("\")
        $SplitBackup=$Backup.substring(0,$Index)
        $Files = Get-ChildItem $Backup -Recurse  | select * | Where-Object {$_.mode -notmatch "h" -and $_.fullname -notmatch $exclude} | select fullname #$_.mode -notmatch "h" -and 

        foreach ($File in $Files) {
            $restpath = $file.fullname.replace($SplitBackup,"")
            try {
                Copy-Item  $file.fullname $($Backupdir+$restpath) -Force -ErrorAction SilentlyContinue |Out-Null
                Logging "INFO" "$file was copied"
            }
            catch {
                $ErrorCount++
                Logging "ERROR" "$file returned an error an was not copied"
            }
            $Items += (Get-item $file.fullname).Length
            $status = "Copy file {0} of {1} and copied {3} MB of {4} MB: {2}" -f $count,$SumItems,$file.Name,("{0:N2}" -f ($Items / 1MB)).ToString(),("{0:N2}" -f ($SumMB / 1MB)).ToString()
            $Index=[array]::IndexOf($BackupDirs,$Backup)+1
            $Text="Copy data Location {0} of {1}" -f $Index ,$BackupDirs.Count
            Write-Progress -Activity $Text $status -PercentComplete ($Items / $SumMB*100)  
            if ($File.Attributes -ne "Directory") {$count++}
        }
    }
    $SumCount+=$Count
    $SumTotalMB="{0:N2}" -f ($Items / 1MB) + " MB of Files"
    Logging "INFO" "----------------------"
    Logging "INFO" "Copied $SumCount files with $SumTotalMB"
    Logging "INFO" "$ErrorCount Files could not be copied"
	if($ErrorCount -ne 0){
	  exit 1
	}


    # Send e-mail with reports as attachments
    if ($SendEmail -eq $true) {
        $EmailSubject = "Backup Email $(get-date -format MM.yyyy)"
        $EmailBody = "Backup Script $(get-date -format MM.yyyy) (last Month).`nYours sincerely `Matthew - SYSTEM ADMINISTRATOR"
        Logging "INFO" "Sending e-mail to $EmailTo from $EmailFrom (SMTPServer = $EmailSMTP) "
        ### the attachment is $log 
        Send-MailMessage -To $EmailTo -From $EmailFrom -Subject $EmailSubject -Body $EmailBody -SmtpServer $EmailSMTP -attachment $Log 
    }
}


#create Backup Dir



Create-Backupdir
Logging "INFO" "----------------------"
Logging "INFO" "Start the Script"

#Check if Backupdir needs to be cleaned and create Backupdir
$Count=(Get-ChildItem $Destination | where {$_.Attributes -eq "Directory"}).count
Logging "INFO" "Check if there are more than $Versions Directories in the Backupdir"

if ($count -gt $Versions) 
{

    Delete-Backupdir
}


$CountZip=(Get-ChildItem $Destination | where {$_.Attributes -eq "Archive" -and $_.Extension -eq ".zip"}).count
Logging "INFO" "Check if there are more than $Versions Zip in the Backupdir"

if ($CountZip -gt $Versions) {

    Delete-Zip 

}

#Check if all Dir are existing and do the Backup
$CheckDir=Check-Dir

if ($CheckDir -eq $false) {
    Logging "ERROR" "One of the Directory are not available, Script has stopped"
	exit 1
} else {
    Make-Backup

    $Enddate=Get-Date #-format dd.MM.yyyy-HH:mm:ss
    $span = $EndDate - $StartDate
    $Minutes=$span.Minutes
    $Seconds=$Span.Seconds

    Logging "INFO" "Backupduration $Minutes Minutes and $Seconds Seconds"
    Logging "INFO" "----------------------"
    Logging "INFO" "----------------------" 

    if ($Zip)
    {
        Logging "INFO" "Compress the Backup Destination"
		Logging "INFO" "Use Powershell Compress-Archive"
	
		if ($UseStaging -and $Zip)
		{
			Logging "INFO" "Zippping to Staging"
			$text = "Zippping to "+$Staging
			Logging "INFO" $text
			
			$Zip=$Staging+("\"+$Backupdir.Replace($Staging,'').Replace('\','')+".zip")  

			$text = "Zippping file "+$Zip
			Logging "INFO" $text
			
			Compress-Archive -Path $Backupdir -DestinationPath $Zip -CompressionLevel Optimal -Force
			
			Logging "INFO" "Move Zip to Destination"
			$text = "Moving to "+$Destination
			Logging "INFO" $text
			
			Copy-Item -Path $Zip -Destination $Destination

			if ($ClearStaging)
			{
				Logging "INFO" "Clear Staging"
				#Get-ChildItem -Path $Staging -Recurse -Force | remove-item -Confirm:$false -Recurse
				Get-ChildItem -Path $Staging -Include *.* -Recurse | foreach { $_.Delete()}
			}

		}
		else
		{
			Logging "INFO" "Zippping to Destination"
			$text = "Destination is "+$Destination
			Logging "INFO" $text
			
			$dest=$Destination+("\"+$Backupdir.Replace($Destination,'').Replace('\','')+".zip")  

			$text = "Zippping file "+$dest
			Logging "INFO" $text
			Compress-Archive -Path $Backupdir -DestinationPath $dest -CompressionLevel Optimal -Force
		}


        If ($RemoveBackupDestination)
        {
            Logging "INFO" "Backupduration $Minutes Minutes and $Seconds Seconds"

            #Remove-Item -Path $BackupDir -Force -Recurse 
            get-childitem -Path $BackupDir -recurse -Force  | remove-item -Confirm:$false -Recurse
            get-item -Path $BackupDir   | remove-item -Confirm:$false -Recurse
        }
    }
}

Write-Host "Done"
$text = "Exit Code: "+$LastExitCode
Write-Host $text
exit $LastExitCode