﻿#
# Module manifest for module 'PoshOpnSense'
#
# Generated by: pvz
#
# Generated on: 2016-07-19
#

@{

# Script module or binary module file associated with this manifest.
# RootModule = ''

# Version number of this module.
ModuleVersion = '1.0'

# ID used to uniquely identify this module
GUID = '79c6e834-0057-48be-bc02-a749a24c7bae'

# Author of this module
Author = 'pvz'

# Company or vendor of this module
CompanyName = 'Unknown'

# Copyright statement for this module
Copyright = '(c) 2016 pvz. All rights reserved.'

# Description of the functionality provided by this module
# Description = ''

# Minimum version of the Windows PowerShell engine required by this module
# PowerShellVersion = ''

# Name of the Windows PowerShell host required by this module
# PowerShellHostName = ''

# Minimum version of the Windows PowerShell host required by this module
# PowerShellHostVersion = ''

# Minimum version of Microsoft .NET Framework required by this module
# DotNetFrameworkVersion = ''

# Minimum version of the common language runtime (CLR) required by this module
# CLRVersion = ''

# Processor architecture (None, X86, Amd64) required by this module
# ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
# RequiredModules = @()

# Assemblies that must be loaded prior to importing this module
# RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
# ScriptsToProcess = @()

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
# FormatsToProcess = @()

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
NestedModules = @('OpnSenseXMLConfig.psm1', 'OpnSenseVLAN.psm1', 'OpnSenseInterface.psm1')

# Functions to export from this module
FunctionsToExport = @( `
    # OpnSenseXMLConfig.psm1
    'Get-OpnSenseXMLConfig',
    'Out-OpnSenseXMLConfig',
    # OpnSenseVLAN.psm1
    'New-OpnSenseVLAN',
    'Set-OpnSenseVLAN',
    'Get-OpnSenseVLAN',
    'Remove-OpnSenseVLAN'
    # OpnSenseInterface.psm1
    'New-OpnSenseInterface',
    'Set-OpnSenseInterface',
    'Get-OpnSenseInterface',
    'Remove-OpnSenseInterface'
)

# Cmdlets to export from this module
CmdletsToExport = '*'

# Variables to export from this module
VariablesToExport = '*'

# Aliases to export from this module
AliasesToExport = '*'

# List of all modules packaged with this module
# ModuleList = @()

# List of all files packaged with this module
# FileList = @() 

# Private data to pass to the module specified in RootModule/ModuleToProcess
# PrivateData = ''

# HelpInfo URI of this module
# HelpInfoURI = ''

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}

