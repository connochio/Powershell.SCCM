## Dell warranty information

These script and companion .mof files will allow for the warranty information for Dell assets to be inventoried by SCCM.
There are 2 versions of this, both of which achieve the same result via different recording methods.

The first method uses the Windows registry as the location to store the information
The second method creates and uses a new WMI class as the location to store the information.

#### Dependancies

For this script to work, you must have access to a Dell API Key and Secret to generate an authorisation token.
You will also only be able to apply this script to a Windows 7 or greater machine.

#### Implementation


