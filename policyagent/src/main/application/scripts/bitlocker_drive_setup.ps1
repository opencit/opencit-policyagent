param(
[Parameter(Mandatory=$True)]
[string]$drive
)

$log_file = "C:\Program Files (x86)\Intel\Policyagent\logs\bitlockersetup.log"
New-Item $log_file -type file -force
"######################## Setting up bitlocker drive on $drive ############################" | Out-file $log_file -Append

$feature = Get-WindowsFeature -Name Bitlocker | fl Installed | findstr.exe Installed
If($?)
{
	$isInstalled = $feature.Split(':')[1].Trim()
}
Else
{	
	echo "Unable to retrieve the windows feature list"
	return $?
}
If($isInstalled)
{
	(Get-Date).ToString() +  " Bitlocker present. Proceeding with the setup." | Out-file $log_file -Append
}
Else
{	
	(Get-Date).ToString() + " Bitlocker not installed!" | Out-file $log_file -Append
	(Get-Date).ToString() + " Please install Bitlocker and restart the machine with following command :" | Out-file $log_file -Append
	(Get-Date).ToString() + " Install-WindowsFeature Bitlocker -Restart" | Out-file $log_file -Append
	(Get-Date).ToString() + " Once done, re-run the policyagent installer" | Out-file $log_file -Append
	return $isInstalled
}

$key_file = "C:\Program Files (x86)\Intel\Policyagent\configuration\bitlocker.key"
Get-Random | Out-File $key_file

#Get-Random | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString | Out-File $key_file
(Get-Date).ToString() + " Key generated for bit-locker drive at " + $key_file | Out-file $log_file -Append

$SecureString = Get-Content $key_file | ConvertTo-SecureString -AsPlainText -Force

Add-BitLockerKeyProtector -MountPoint $drive -Password $SecureString -PasswordProtector

If($?)
{
	(Get-Date).ToString() + " Password added as protector for drive $drive" | Out-file $log_file -Append
	manage-bde -on $drive":"
	while($?)
	{
		$status = Get-BitLockerVolume -MountPoint $drive  | fl EncryptionPercentage | findstr.exe EncryptionPercentage
		$percentage = $status.Split(':')[1].Trim()
		if($percentage.equals('100'))
		{
			(Get-Date).ToString() + " Drive Encryption completed!" | Out-file $log_file -Append
			break;
		}
		Start-Sleep -s 2
	}
	If($?.Equals("False"))
	{
		(Get-Date).ToString() + " Drive Encryption failed!" | Out-file $log_file -Append
		return $?
	}
}


#Register service which calls binary to unlock drive after boot
New-Service -Name UnlockDrive -BinaryPathName "C:\Program Files (x86)\Intel\Policyagent\bin\BitLocker.exe" -DisplayName "Intel CIT UnlockDrive" -StartupType Automatic
(Get-Date).ToString() + " UnlockDrive registered as autostart service to unlock drive on bootup of machine" | Out-file $log_file -Append

#Start UnlockDrive service
Start-Service UnlockDrive
(Get-Date).ToString() + " UnlockDrive service started" | Out-file $log_file -Append

"######################## Bitlocker drive setup complete for $drive ############################" | Out-file $log_file -Append

