# PoshOpnSense
This (will become) a PowerShell module to manipulate OPNsense's config.xml format.

General functionality/workflow will be:

- Download configuration file by using the backup export functionality of OPNsense.
- Parse and load configuration file into memory
- Use PowerShell cmdlets provided by this module to interrogate and manipulate select aspects of the configuration
- Write out a new config.xml file.
- Upload configuration file to the OPNsense box.

I do not aim for complete coverage of all of config.xml, just enough to scratch my own itches. Patches welcome!

# Usage

1. Clone the repository into C:\Users\yourusername\Documents\WindowsPowershell\Modules, such that there is a file named C:\Users\yourusername\Documents\WindowsPowershell\Modules\PoshOpnSense\PoshOpnSense.psd1 (if you prefer it elsewhere on your filesystem, read about how to import modules or set PowerShell's module path.
2. Open up Powershell and start working with the cmdlets.
