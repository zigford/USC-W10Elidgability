Add-Type -AssemblyName System.Windows.Forms

function LogEntry {
Param($msg)
    Write-Host $msg
    $txtOutput.Text+="$msg`r`n"
    $txtOutput.Update()
    $txtOutput.Refresh()
   
}
$button3_Click={
Param($File)
#add here code triggered by the event
    If (-Not (Get-Module -ListAvailable USC-SCCM)) {
        LogEntry "Importing SCCM Module"
        Import-Module '\\usc.internal\usc\appdev\General\SCCMTools\Scripts\Modules\USC-SCCM'
    } Else { LogEntry "SCCM Module already imported" }
    If ($txtSingleComp.Text -eq '' -or $txtSingleComp.Text -eq 'Enter single machine here to check') {
        $ComputersToCheck = Get-Content ($txtCompList.Text).Trim('"')
    } Else {
        $ComputersToCheck = $txtSingleComp.Text
    }
    Switch ($ComputersToCheck.Count) {
        0 { LogEntry "No Computers to check, look in your source file" }
        1 { LogEntry "1 Computer to check, possible incorrect source file" }
        Default { LogEntry "$($ComputersToCheck.Count) computers to check" }
    }
    Start-Sleep -Seconds 5
    $AppPath = "$Env:Localappdata\USC\Elidgable"
    If (-Not (Test-Path -Path $AppPath)) {
        New-Item -ItemType Directory -Path $AppPath -Force
    }
    $Collections = @(
        [PSCustomObject]@{Result = 'Elidgable';Collection='All Machines Elidgable for Windows 10'},
        [PSCustomObject]@{Result = 'Disk Space';Collection='All Machines Inellidgable for Windows 10 - Disk Space'},
        [PSCustomObject]@{Result = 'End of Life';Collection='All Machines Inellidgable for Windows 10 - End Of Life'},
        [PSCustomObject]@{Result = 'Client Version';Collection='All Machines Inellidgable for Windows 10 - Client Version'},
        [PSCustomObject]@{Result = 'Virtual Machine';Collection='All Machines Inellidgable for Windows 10 - Virtual Machines'},
        [PSCustomObject]@{Result = 'Student OU';Collection='All Machines Inellidgable for Windows 10 - Student OU'},
        [PSCustomObject]@{Result = 'Other';Collection='All Machines Inellidgable for Windows 10 - Other'},
        [PSCustomObject]@{Result = 'Windows 10';Collection='All USC Windows 10 Devices'}
    )
    $Log = @()
    ForEach ($Collection in $Collections) {
        If ((-Not (Test-Path -Path "$AppPath\$($Collection.Result).txt")) -or (Get-Item -Path "$AppPath\$($Collection.Result).txt").LastWriteTime -lt (Get-Date).AddDays(-1)) {
            LogEntry "Creating Cache for collection $($Collection.Collection)"
            Get-CfgCollectionMembers -Collection $Collection.Collection | Select-Object -ExpandProperty ComputerName | Out-File -FilePath "$AppPath\$($Collection.Result).txt" -Force
        }

        $ComputersToCheck | ForEach-Object {
            $Comp = $_
            If ($_ -in (Get-Content "$AppPath\$($Collection.Result).txt")) {
                $IsInACollection = $True
                $UserName = ginv $Comp | select -expand LastLogonUserName
                Switch ($Collection.Result) {
                    'Disk Space' {
                        If (Test-Path -Path "\\$Comp\d$") {
                            #LogEntry "Succesfully Connected to $_ D:"
                            $FileCount = (Get-ChildItem -Path \\$Comp\d$).Count
                            If ($FileCount -eq 0) {
                                $Log += [PSCustomObject]@{Computer=$Comp;User=$UserName;Result="Low disk space";Action="Merge Disks"}
                            } Else {
                                $Log += [PSCustomObject]@{Computer=$Comp;User=$UserName;Result="Low disk space";Action="Remove $FileCount and merge disks"}
                            }
                        } Else {
                            $Log += [PSCustomObject]@{Computer=$Comp;User=$UserName;Result="Low disk space";Action="Call client to arrange merge"}
                        }
                    }
                    'Client Version' {
                        $Log += [PSCustomObject]@{Computer=$Comp;User=$UserName;Result="Old Client";Action="Force reinstall client from SCCM"}
                    }
                    'Student OU' {
                        $Log += [PSCustomObject]@{Computer=$Comp;User=$UserName;Result="Student OU";Action="Move computer or notify client"}
                    }
                    'Windows 10' {
                        $Log += [PSCustomObject]@{Computer=$Comp;User=$UserName;Result="Windows 10 Computer";Action="No Action Required"} 
                    }
                    'Other' {
                        $Log += [PSCustomObject]@{Computer=$Comp;User=$UserName;Result="Unknown Reason";Action="Contact Jesse or escelate"}
                    }
                    Default { $Log += [PSCustomObject]@{Computer=$Comp;User=$UserName;Result=$Collection.Result } }
                }
            }
        }

    }
    LogEntry "$($Log |Format-Table -Property Computer,User,Result,Action | Out-String -Width 4096)"
    <#Get-CfgCollectionMembers $MainCollection | Select -First 5 | %{
        #Start-Sleep -Seconds 5
        $textOutput.Text += "$($_.ComputerName)`r`n"
        $textOutput.Update()
        $textOutput.Refresh()
        #Write-Host $_.ComputerName
    }
    #>
}
$txtCompList_KeyPress=[System.Windows.Forms.KeyPressEventHandler]{
#Event Argument: $_ = [System.Windows.Forms.KeyEventArgs]
    Write-Host $_.KeyChar
	if($_.KeyChar -eq [System.Windows.Forms.Keys]::Enter)
	{
		If (Test-Path -Path (($txtCompList.Text).Trim('"'))) {
            $button3.Enabled = $True
            $AppPath = "$Env:Localappdata\USC\Elidgable"
            If (-Not (Test-Path -Path $AppPath)) {
                New-Item -ItemType Directory -Path $AppPath -Force
            }
            New-Item -Path $AppPath -Name Settings.txt -Value $txtCompList.Text.Trim('"') -Force
        } else {
            Write-Host "Failed to find file"
        }
	} else {
        Write-Host "Key didn't match enter"
    }
}

$Form = New-Object system.Windows.Forms.Form
$Form.AutoScaleMode = "Font"
$Form.Text = "Check Inelidgable"
$Form.TopMost = $true
$Form.AutoScaleDimensions = new-object System.Drawing.SizeF @([double] 6, [double] 13)
$Form.ClientSize ="660,376"
$Form.AutoSizeMode = "GrowOnly"

$button3 = New-Object system.windows.Forms.Button
$button3.Text = "Go"
$button3.AutoSize = $true
$button3.Enabled = $False
$button3.Add_Click($button3_Click)
$button3.Anchor = 'Top','Right'
#$button3 = $null
$button3.location = new-object system.drawing.point(($Form.Width - ($button3.Width + 20)),1)
#$button3.Font = "Microsoft Sans Serif,15,style=Bold"
$Form.controls.Add($button3)
$txtCompList = New-Object System.Windows.Forms.TextBox
$txtCompList.Text = "Paste in path to computer list"
$txtCompList.AutoSize = $true
$txtCompList.ClientSize = "400,10"
$txtCompList.Font = "Microsoft Sans Serif,10"
$txtCompList.Location = new-object System.Drawing.point(1,1)
$txtCompList.add_KeyPress($txtCompList_KeyPress)
$txtOutput = New-Object System.Windows.Forms.TextBox
$txtOutput.Location = new-object System.Drawing.point(1,($txtCompList.Height + 5))
$txtOutput.ClientSize = "$($Form.Width - 22),$($Form.Height - $txtCompList.Height - 50)" 
$txtOutput.AutoSize = $true
$txtOutput.Multiline = $true
$txtOutput.ScrollBars = "Vertical"
$txtOutput.Font = "Courier,10"
$txtOutput.ScrollToCaret()
$Form.Controls.Add($txtCompList)
$Form.Controls.Add($txtOutput)
$SettingsFile = "$env:LocalAppData\USC\Elidgable\Settings.txt"
If (Test-Path -Path $SettingsFile) {
    $txtCompList.Text = Get-Content $SettingsFile
    $button3.Enabled = $True
}
$txtSingleComp = New-Object System.Windows.Forms.TextBox
$txtSingleComp.Text = "Enter single machine here to check"
$txtSingleComp.AutoSize = $true
$txtSingleComp.ClientSize = "200,10"
$txtSingleComp.Location = new-object System.Drawing.Point(($txtCompList.Width + 5),1)
$Form.Controls.Add($txtSingleComp)

[void]$Form.ShowDialog()
#$Form.Dispose()
<#LogEntry "Updating Collection Data. Please Wait"

LogEntry "Ready"
#>