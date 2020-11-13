# Dell Warranty Information Script

These script and companion .mof files will allow for the warranty information for Dell assets to be inventoried by SCCM.
There are 2 versions of this, both of which achieve the same result via different recording methods.

The first method uses the Windows registry as the location to store the information
The second method creates and uses a new WMI class as the location to store the information.

## Dependancies

For this script to work, you must have access to a Dell API Key and Secret to generate an authorisation token.

This Script is confirmed to work on:  
Windows 10

It *Should* work on:  
Windows Server 2016  
Windows Server 2012/2012R2  
Windows 8

## Implementation

#### To deploy the script within your SCCM environment, please follow the below guide:

1. Create a new folder on your SCCM instance an copy the .ps1 file to it
2. Create a new package within 'Software Library > Packages' with the content location set to the folder created above
3. Select your new package, right-click and select 'Create Program', then selecting 'Standard Program'
4. Enter the following into the 'Program' field, replacing xxxx with the relevant Api Key and Api Secret without any quotes  
`%Windir%\Sysnative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -Command ".\Get-DellWarranty.ps1 -ApiKey xxxxx -ApiSecret xxxxx"`
5. Change 'Run:' to 'Hidden'
6. Change 'Programs can run:' to 'Whether or not a user is logged on'
6. Change 'Run mode:' to 'Run with administrative rights'

#### To enable SCCM collection of this new inventory information:

1. Go to your 'Default Client Settings' under 'Administration > Client Settings'
2. Open the default client settings, and select 'Hardware Inventory' from the left-hand list
3. Click 'Set Classes ...' and then click 'Import'
4. In the file selection that opens, select the companion .mof for the script you have deployed
4.
