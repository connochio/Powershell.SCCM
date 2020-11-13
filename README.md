# Powershell-SCCM

In this repo are some helpful PowerShell scripts and their accompanying mof files for extending the SCCM client hardware inventory withh relevant information.

Instructions on how to use or implement these are contained within the relevant folders, but these are just suggested implementation procedures. Feel free to use and/or amend them to your own needs if required.

## Browser Extensions

A script to find browser extensions installed on a machine across all user profiles, and add them to a new WMI class to be reported by system inventory tools such as SCCM.

Currently includes:
* Microsoft Edge
* Google Chrrome
* Mozilla Firefox
* Brave Browser
* Microsoft Edge Chromium

If new browsers are required, please log an issue.

## Dell Warranty

A script for gathering warranty information using the Dell API and adding them to either a registry key or a new WMI class to be reported by system inventory tools such as SCCM.  

It includes these attributes for a Dell asset:
* Warranty Start Date
* Warranty End Date
* Dell UID
* Support Entitlement
* Ship Date
* Service Tag
* Model

This is a modified version of the Get-DellWarranty PowerShell module contained here:  
https://github.com/connochio/Powershell-Dell-Warranty-Check
