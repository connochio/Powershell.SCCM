#================
#     Setup 
#================

Start-Transcript -Path "$env:SystemRoot\Temp\BrowserInventory.log"

$ErrorActionPreference = "SilentlyContinue" # Override the default to hide errors.  Comment this line to show standard error messages.

$boolInventoryChrome = $true
$boolInventoryBrave = $true
$boolInventoryEdgeChrome = $true
$boolInventoryMozilla = $true
$boolInventoryEdge = $true

$strChromeProfilePathAppend = "AppData\Local\Google\Chrome\User Data\Default\Extensions"
$strBraveProfilePathAppend = "AppData\Local\BraveSoftware\Brave-Browser\User Data\Default\Extensions"
$strEdgeChromeProfilePathAppend = "AppData\Local\Microsoft\Edge\User Data\Default\Extensions"
$strMozillaProfilePathAppend = "AppData\Roaming\Mozilla\FireFox\Profiles"
$strEdgeProfilePath = "$env:ProgramFiles\WindowsApps"

$CustomWMIClassName = "CM_BrowserExtensions_v1"

$boolExcludeCommonExtensions = $true  #optional, if you want to exclude the following common browser extensions (these are typically preinstalled or mass installed)
$strCommonGoogleExtensions = 'Google Docs','Google Sheets','Google Slides','Google Drive','YouTube','Gmail','Google Docs Offline','Chrome Web Store Payments','Chrome Media Router'
$strCommonMozillaExtensions = ''
$strCommonEdgeExtensions = ''
$strCommon3rdPartyExtensions = ''

$boolInventoryPreinstalledMicrosoftApps = $false # there are hundreds of preinstalled Apps from Microsoft.  If you want to inventory them, set this to $true, otherwise they will be skipped

#Combine the excluded extension lists for use later
$strCommonExtensions = $strCommonGoogleExtensions + $strCommonMozillaExtensions + $strCommonEdgeExtensions + $strCommon3rdPartyExtensions

#================
#   Functions
#================

# Function to create the custom WMI class
# Note that, once the class has been created on a device, it must be manually deleted if you want to add any additional columns of data
Function Prepare-Wmi-Class()
	{
		Get-WMIObject $CustomWMIClassName -ErrorAction SilentlyContinue -ErrorVariable strWMIClassError | Out-Null

		# If the GET failed, the class doesn't exist, so create it.  If not, it exists so clean it out.
		If ($strWMIClassError)
			{
				Write-Host "WMI Class $CustomWMIClassName does not exist.  Try to create it.`n" -ForegroundColor Green

				Try
					{
						$newClass = New-Object System.Management.ManagementClass("root\cimv2", [String]::Empty, $null); 

						$newClass["__CLASS"] = "$CustomWMIClassName";

						$newClass.Qualifiers.Add("Static", $true)
						$newClass.Properties.add("Counter", [System.Management.CimType]::UInt32, $false)
						$newClass.Properties.add("ProfilePath", [System.Management.CimType]::String, $false)
						$newClass.Properties.add("FolderDate", [System.Management.CimType]::DateTime, $false)
						$newClass.Properties.add("FolderName", [System.Management.CimType]::String, $false)
						$newClass.Properties.add("Browser", [System.Management.CimType]::String, $false)
						$newClass.Properties.add("Name", [System.Management.CimType]::String, $false)
						$newClass.Properties.add("Version", [System.Management.CimType]::String, $false)
						$newClass.Properties.add("ScriptLastRan", [System.Management.CimType]::DateTime, $false)
						$newClass.Properties["Counter"].Qualifiers.Add("Key", $true)
						$newClass.Put()
					}
					Catch
						{
							Write-Host "Could not create WMI class" -ForegroundColor Red
        					Exit 1
						}
			}
			Else
				{
					Write-Host "WMI Class $CustomWMIClassName exists.  Clear it out and proceed with logging.`n" -ForegroundColor Green

					# Remove all existing instances of the WMI class
					Get-WmiObject $CustomWMIClassName | Remove-WmiObject
				}
	}

# Extract the Mozilla files
Function ExtractMozillaExtensionPackage ($strMozillaExtensionPackagePath, $strBrowserDataToFind)
	{
		# If the temp extraction directory already exists, remove it	
		$strTempFolderRoot = "$strMozillaExtensionPackagePath\SLPS_TEMP"
		If (Test-Path $strTempFolderRoot) {Remove-Item $strTempFolderRoot -Recurse -Force}

		# Get the list of XPI files
		$arrExtensionPackages = (Get-ChildItem -Path $strMozillaExtensionPackagePath -Filter "*.xpi" -Recurse).FullName

		# Bind to each XPI file and unzip it
		ForEach ($objExtensionPackage in $arrExtensionPackages)
			{
				$objArchiveFile = Get-ChildItem -Path $objExtensionPackage
				$objArchiveName = $objArchiveFile.Name

				# Open the XPI file
				$objArchive = [System.IO.Compression.ZipFile]::OpenRead($objArchiveFile)

				# Try to unzip it
				Try
					{
						# Define the target of the extracted files
						$strTempFolder = "$strTempFolderRoot\$objArchiveName".Trim(".xpi") + "\Extracted"

						# If the temp folder doesn't exist, create it
						If (!(Test-Path $strTempFolder)) {New-Item -ItemType "Directory" $strTempFolder | Out-Null}

						# Extract the files
						[System.IO.Compression.ZipFileExtensions]::ExtractToDirectory($objArchive, $strTempFolder)

					}
					Catch
						{
							Write-Host "Error extracting $objArchiveName $_" -ForegroundColor Red
						}

			}

		# Read the manifest files
		GetManifestFiles $strTempFolderRoot $strBrowserDataToFind "manifest.json"

		# Remove the temp directory when complete - this isn't really necessary, as it gets removed the next time the script runs.  It's also helpful for troubleshooting to leave it.
#		Remove-Item $strTempFolderRoot -Recurse -Force

	}

# Inventory the browser extensions
Function InventoryExtensions  ($strUserProfilePath, $strBrowserDataToFind)
	{
		# Browser specific searches

		# For Chrome, just search the given path
		If ($strBrowserDataToFind -eq "CHROME") 
			{
				# Append the Chrome path
				$strManifestSearchPath = $strUserProfilePath + "\" + $strChromeProfilePathAppend

				# Read the manifest files
				GetManifestFiles $strManifestSearchPath $strBrowserDataToFind "manifest.json"
			}

		# For Brave, do the same
        If ($strBrowserDataToFind -eq "BRAVE") 
			{
				# Append the Chrome path
				$strManifestSearchPath = $strUserProfilePath + "\" + $strBraveProfilePathAppend

				# Read the manifest files
				GetManifestFiles $strManifestSearchPath $strBrowserDataToFind "manifest.json"
			}

		# Edge Chromium, do it again
        If ($strBrowserDataToFind -eq "EDGE_CHROMIUM") 
			{
				# Append the Chrome path
				$strManifestSearchPath = $strUserProfilePath + "\" + $strEdgeChromeProfilePathAppend

				# Read the manifest files
				GetManifestFiles $strManifestSearchPath $strBrowserDataToFind "manifest.json"
			}

		# If it's Mozilla, we have to extract the packages into a temp folder first
		If ($strBrowserDataToFind -eq "MOZILLA") 
			{
				If (Test-Path "$strUserProfilePath\$strMozillaProfilePathAppend") 
					{
						# Set the path to the profiles.
						$arrMozillaProfiles = Get-ChildItem "$strUserProfilePath\$strMozillaProfilePathAppend" | Where-Object { $_.PSIsContainer}

						# For each profile folder, we need to extract the XPI files (zipped extension pacakges) into a temp folder, then run the Manifest check
						ForEach ($objMozillaProfile in $arrMozillaProfiles)
							{
								# Run the Extraction routine against the Extension profile folder
								ExtractMozillaExtensionPackage "$($objMozillaProfile.FullName)\Extensions" $strBrowserDataToFind
							}
					}
			}

		# For Edge, we'll use PowerShell cmdlets to get the data
		If ($strBrowserDataToFind -eq "EDGE") 
			{
				# Set the Edge path
				$strManifestSearchPath = $strEdgeProfilePath

				# Get the username from the profile path
				$strAppxUser = $strUserProfilePath.Replace("$strProfileRoot\","")

				# Get a list of Apps for this user
				$objUserAppxPackages = Get-AppxPackage -User $strAppxUser

				# For each app, run the GetManifest function
				ForEach ($objUserAppxPackage in $objUserAppxPackages)
					{
						# If flag is not set to $true and the App Publisher contains "Microsoft", don't inventory it. Otherwise, proceed with the inventory.
						If ($boolInventoryPreinstalledMicrosoftApps -eq $true -or ($boolExcludePreinstalledMicrosoftEdgeExtensions -ne $true -and $objUserAppxPackage.Publisher -notlike "*Microsoft*"))
							{
								# Clear the variables
								$global:dtFolderDateToRecord = Get-Date
								$global:strExtensionFolderNameToRecord = ""

								# Set the FolderName to the installation folder
								$global:strExtensionFolderNameToRecord = ($objUserAppxPackage.InstallLocation).Replace("$strEdgeProfilePath\","")

								# Try to get the date from the installation folder
								Try
									{
										$global:dtFolderDateToRecord = Get-ChildItem $objUserAppxPackage.InstallLocation | Select-Object -Last 1 | ForEach-Object { ($_.lastwritetime.tostring("yyyyMMddhhmmss"))+ '.000000-000'  } 
									}
									Catch 
										{
											Write-Host "Could not record the date for $($objUserAppxPackage.InstallLocation): $_"
											$global:dtFolderDateToRecord = "19000101000000" + '.000000-000'
										}

								# Read the manifest files
								ReadAppxManifestXML $objUserAppxPackage.PackageFullName $strAppxUser $strBrowserDataToFind
							}
							#Else {Write-Host "$($objUserAppxPackage.PackageFullName) - Skipped"}
					}
			}
	}

# Get a list of all manifest files in the given path
Function GetManifestFiles ($strManifestSearchPath, $strBrowserDataToFind, $strDefaultManifestFileName)
	{
		# Clear the variables
		$global:dtFolderDateToRecord = ""
		$global:strExtensionFolderNameToRecord = ""

		# Search the path
		If (Test-Path $strManifestSearchPath)
			{
				Try
					{
						# Get an array of Extension folders from the Manifest File Search Path - this should be a list of folders, each containing the Extension files
						$arrExtensionFolders = Get-ChildItem $strManifestSearchPath | Where-Object { $_.PSIsContainer}

						# Go through the array of Extension folders
						ForEach ($objExtensionFolder in $arrExtensionFolders) 
							{
								# If this is Chrome, there will be a list of Version folders under the Extension folder so we need to iterate those.  For other browsers, we'll fake it.
								$arrExtensionVersionFolders = Get-ChildItem $objExtensionFolder.FullName | Where-Object { $_.PSIsContainer}

								# Go through the version folders in the extension folder
								ForEach ($objExtensionVersionFolder in $arrExtensionVersionFolders)
									{
										# Record the Extension Folder Name
										$global:strExtensionFolderNameToRecord = $objExtensionFolder.Name

										# Record the Extension Folder Date
										$global:dtFolderDateToRecord = Get-ChildItem $objExtensionVersionFolder.FullName | Select-Object -Last 1 | ForEach-Object { ($_.lastwritetime.tostring("yyyyMMddhhmmss"))+ '.000000-000'  } 

										# Inside each version folder, get the manifest.json file
										$strManifestFilePath = (Get-ChildItem -Path $objExtensionVersionFolder.FullName -filter $strDefaultManifestFileName -Recurse -ErrorAction SilentlyContinue).FullName

										# If the manifest file exists, read it
										If ($strManifestFilePath)
											{
												# If the Manifest file is manifest.json, call that function to find the Extension Name and Version
												If ($strDefaultManifestFileName = "manifest.json")
													{
														ReadManifestJSONFile $strManifestFilePath
													}

												# Record the info to WMI
												RecordExtensionsToWMI $strExtensionNameToRecord $strUserProfilePath $dtFolderDateToRecord $strExtensionFolderNameToRecord $strBrowserDataToFind $strVersionToRecord
											}
									}
							}
					}
					Catch
						{Write-Host "Error reading manifest files $_" -ForegroundColor Red}
			}
	}

# Read the required info from the manifest.json file
Function ReadManifestJSONFile ($strManifestFilePath)
	{
		# Clear the variables
		$strVersionLabelFromManifest = ""
		$strNameLabelFromManifest = ""
		$strVersionValueFromManifest = ""
		$strNameValueFromManifest = ""
		$global:strVersionToRecord = ""
		$global:strExtensionNameToRecord = ""		

		If (Test-Path $strManifestFilePath) 
			{

				ForEach ($objManifestFilePath in $strManifestFilePath)
					{
						# Read the Manifest file into an object
						$objManifestJSONFile = Get-Content $strManifestFilePath | ConvertFrom-Json

						# Inside manifest.json file, read the Version info
						$strVersionValueFromManifest = $objManifestJSONFile.Version

						# Record the version info
						$global:strVersionToRecord = $strVersionValueFromManifest

						# Inside manifest.json file, read the Name info
						$strNameValueFromManifest = $objManifestJSONFile.Name

						# If Name starts with underscores (i.e. "__MSG_APP_NAME__") then look in the messages.json files for a language specific name.  Otherwise, use the name from the routine above.
					   	If ($strNameValueFromManifest -like "__*") 
							{
								# Get the name to search for  in messages.json
								$strMessageNameToFind = $strNameValueFromManifest.Trim("_").Trim("MSG_")

							   	# If the variables already exist, remove them
								If ($strMessagesFile1) {Remove-Variable -Name strMessagesFile1}
								If ($strMessagesFile2) {Remove-Variable -Name strMessagesFile2}

								# Set the Messages folder variables to the 2 likely English language folders
								$objManifestFileFolder = (Get-ChildItem $strManifestFilePath).DirectoryName

								$strMessagesFile1 = "$objManifestFileFolder\_locales\en\messages.json"
							    $strMessagesFile2 = "$objManifestFileFolder\_locales\en_US\messages.json"

								# Call the function to search the messages.json file
								If (Test-Path $strMessagesFile1)
									{
										ReadMessagesFile $strMessagesFile1 $strMessageNameToFind
									}

								# If the name wasn't found in the first file, search the second
								If ($strExtensionNameToRecord -eq "" -and (Test-Path $strMessagesFile2))
									{
										# Call the function with the second file
										ReadMessagesFile $strMessagesFile2 $strMessageNameToFind
									}

								# If the name wasn't found in the second file, record it as Unknown
								If ($strExtensionNameToRecord -eq "") {$strExtensionNameToRecord = "Unknown"}

							}
							Else
								{$global:strExtensionNameToRecord = $strNameValueFromManifest}
					}

			}
	}

# Read the required info from the AppxManifest.XML
Function ReadAppxManifestXML ($strAppxManifestPackageName, $strAppxUser, $strBrowserDataToFind)
	{
		# Clear the variables
		$global:strExtensionNameToRecord = ""		
		$global:strVersionToRecord = ""

		# Record the package name
		$global:strExtensionNameToRecord = (Get-AppxPackageManifest -Package $strAppxManifestPackageName -User $strAppxUser).Package.Properties.DisplayName

		#Write-Host "Name: $strExtensionNameToRecord"

		# Record the package version
		$global:strVersionToRecord = (Get-AppxPackageManifest -Package $strAppxManifestPackageName -User $strAppxUser).Package.Identity.Version

		#Write-Host "Version: $strVersionToRecord"

		# Record the info to WMI
		RecordExtensionsToWMI $strExtensionNameToRecord $strUserProfilePath $dtFolderDateToRecord $strExtensionFolderNameToRecord $strBrowserDataToFind $strVersionToRecord
	}	

# Read the required info from the messages.json file
Function ReadMessagesFile ($strMessagesFilePath, $strMessageNameToFind)
	{
		# Clear the variable
		$global:strExtensionNameToRecord = ""

		# Search the given folder to find a messages.json file
		If (Test-Path $strMessagesFilePath) 
			{
				# Clear the variables
				$strNameLabelFromMessages = ""
				$strNameValueFromMessages = ""
				$intMessagesLineNumber = ""
				$intMessagesNextLineNumber = ""

				# Search the messages.json file to find the specified text and get the line number
		      	$intMessagesLineNumber = Select-String """$strMessageNameToFind""" $strMessagesFilePath | ForEach-Object {$_.LineNumber}

				# Get the content of the next line as that one should have the name
		      	$intMessagesNextLineNumber = (Get-Content $strMessagesFilePath)[$intMessagesLineNumber]

				# Trim the Value of any spaces, commas, and double-quotes   #Value 6 should be the name
		      	$strNameLabelFromMessages,$strNameValueFromMessages = $intMessagesNextLineNumber.Split(':').Trim().Trim([Char]0x002c).Trim([Char]0x0022)

		  		# Check to see if Label6 was actually the 'Message' that we were looking for.  Sometimes it's the next (or the next) line.
		  		If ($strNameLabelFromMessages.Trim() -eq "message") {$global:strExtensionNameToRecord = $strNameValueFromMessages} 
					Else
		  				{
							# If it wasn't right, go to the next line, get the content, and trim it.
				          	$intMessagesNextLineNumber = (Get-Content $strMessagesFilePath)[$intMessagesLineNumber+1]
				          	$strNameLabelFromMessages,$strNameValueFromMessages = $intMessagesNextLineNumber.Split(':').Trim().Trim([Char]0x002c).Trim([Char]0x0022)

					  		# Check it again
					  		If ($strNameLabelFromMessages.Trim() -eq "message") {$global:strExtensionNameToRecord = $strNameValueFromMessages} 
								Else
								  	{
										# If it still isn't right, check one more time.  Get the content and trim it.
										$intMessagesNextLineNumber = (Get-Content $strMessagesFilePath)[$intMessagesLineNumber+2]
						          		$strNameLabelFromMessages,$strNameValueFromMessages = $intMessagesNextLineNumber.Split(':').Trim().Trim([Char]0x002c).Trim([Char]0x0022)

										# If it found something that time, record it
										If ($strNameLabelFromMessages.Trim() -eq "message") {$global:strExtensionNameToRecord = $strNameValueFromMessages }
									}
				        }

		  		# If none of those checks found the right name, record the name as Unknown
		  		If ($strExtensionNameToRecord -eq "") {$global:strExtensionNameToRecord = "Unknown"}
	       } 
	}

# Write the specified info into WMI
Function RecordExtensionsToWMI ($strNameWMI, $strProfilePathWMI, $dtFolderDateWMI, $strFolderNameWMI, $strBrowserWMI, $strVersionWMI)
	{
		# Output the Name and Version
		Write-Host -NoNewline "$strBrowserWMI / $strNameWMI / $strVersionWMI"
		#Write-Host -NoNewLine " / $strProfilePathWMI / $dtFolderDateWMI / $strFolderNameWMI / $intBrowserExtensionCount" # Additional logging data

		# Check to see if the Extension name is in the list of Extensions to Include
		If ($boolExcludeCommonExtensions -eq $true) 
			{
		    	If ($strCommonExtensions -match $strExtensionNameToRecord) 
					{
				    	# The extension name is on the list so skip it and output
						Write-Host " - Excluded" -ForegroundColor Red

						Return
					}
		    }

			# Record into WMI
		    (Set-WmiInstance -Path \\.\root\cimv2:$CustomWMIClassName  -Arguments @{
		        Counter=$intBrowserExtensionCount;
		        Name=$strNameWMI;
		        ProfilePath=$strProfilePathWMI;
		        FolderDate=$dtFolderDateWMI;
				FolderName=$strFolderNameWMI;
				Browser=$strBrowserWMI;
		        Version=$strVersionWMI;
		        ScriptLastRan=$dtScriptRunTime}) | Out-Null

				# Increment the counter  
				$global:intBrowserExtensionCount++

				Write-Host " - Recorded" -ForegroundColor Green

	}

#================
#     Script
#================

# Set internal script variables
$global:intBrowserExtensionCount = 1
$strProfileListKey = 'Registry::HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\*'
$strProfilePathsList = Get-ItemProperty -Path $strProfileListKey | Select-Object -Property ProfileImagePath
$strProfileRoot = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList").ProfilesDirectory

# Record the script run time in a WMI formatted variable
$dtScriptRunTime = New-Object -ComObject WbemScripting.SWbemDateTime
$dtScriptRunTime.SetVarDate($(Get-Date))
$dtScriptRunTime = $dtScriptRunTime.Value

# Import .NET 4.5 compression utilities
Add-Type -As System.IO.Compression.FileSystem | Out-Null


# Check/Create/Clear the custom WMI class
Prepare-Wmi-Class


# Go through the Windows user profiles and find each of the Chrome and Mozilla extensions
$strProfilePathsList | Foreach-object {

		If ($boolInventoryChrome -eq $true)
			{
				# Check for Chrome Extensions
				InventoryExtensions $_.ProfileImagePath 'CHROME'
			}

		If ($boolInventoryBrave -eq $true)
			{
				# Check for Edge Extensions
				InventoryExtensions $_.ProfileImagePath 'BRAVE'
			}

		If ($boolInventoryEdgeChrome -eq $true)
			{
				# Check for Edge Extensions
				InventoryExtensions $_.ProfileImagePath 'EDGE_CHROMIUM'
			}

		If ($boolInventoryMozilla -eq $true)
			{
				# Check for Mozilla Extensions
				InventoryExtensions $_.ProfileImagePath 'MOZILLA'
			}

		If ($boolInventoryEdge -eq $true)
			{
				# Check for Edge Extensions
				InventoryExtensions $_.ProfileImagePath 'EDGE'
			}
}

Stop-Transcript

<#
#### Hardware Inventory - import to hardware inventory
[ SMS_Report     (TRUE),
  SMS_Group_Name ("Browser Extensions"),
  SMS_Class_ID   ("BrowserExtensions"),
  Namespace ("\\\\\\\\.\\\\root\\\\cimv2")]
class CM_BrowserExtensions_v1 : SMS_Class_Template
{
    [SMS_Report (TRUE),key ]  uint32     Counter;
    [SMS_Report (TRUE)     ]  string     Name;
    [SMS_Report (TRUE)     ]  DateTime   FolderDate;
    [SMS_Report (TRUE)     ]  string     FolderName;
    [SMS_Report (TRUE)     ]  string     ProfilePath;
    [SMS_Report (TRUE)     ]  string     Browser;
    [SMS_Report (TRUE)     ]  DateTime   ScriptLastRan;
    [SMS_Report (TRUE)     ]  string     Version;
};

#>
