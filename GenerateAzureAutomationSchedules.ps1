function GenerateAzureAutomationSchedules
{
<#
.Synopsis
   Generates Azure Automation Schedules on definied hourly interval and minute segements.
.EXAMPLE
   If you haven't already registered an Azure Account, use the following cmdlet to register an account:
   PS > Add-AzureAccount

   List all Azure Automation Accounts:
   PS > Get-AzureAutomationAccount

   Get the Azure Automation Account and save into a variable:
   PS > $AutomationAccount = Get-AzureAutomationAccount -Name <AutomationAccountName>
.EXAMPLE
   PS > $AutomationAccount = Get-AzureAutomationAccount -Name <AutomationAccountName>
   PS > GenerateAzureAutomationSchedules -AutomationAccount $AutomationAccount -Verbose
.EXAMPLE
   Define the Segments hashtable with <Minute>=<FriendlyName>
   PS > $Segments = [ordered]@{
       5 = "5min"
       30 = "30min"
       48 = "48min"
   }

   PS > GenerateAzureAutomationSchedules -AutomationAccount $AutomationAccount -Segments $Segments
.NOTES
   Version: 20141124.1
   Author: Daniel Grenemark
   Email: daniel@grenemark.se
   Twitter: @desek
#>
    [CmdLetBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Microsoft.Azure.Commands.Automation.Model.AutomationAccount]$AutomationAccount,
        [int]$Interval = 1,
        [hashtable]$Segments = [ordered]@{
            2 = "2min"
            5 = "5min"
            10 = "10min"
            15 = "15min"
            30 = "30min"
        }
    )

    BEGIN
    {
        If ($PSVersionTable.PSVersion.Major -lt 4)
        {
            Throw "Requires Powershell version 4 or later. You have version $($PSVersionTable.PSVersion.Major)."
        }
        If (@(Get-Module -Name Azure).Count -lt 1)
        {
            Throw "Requires Azure Powershell module. Latest release found at https://github.com/Azure/azure-sdk-tools/releases"
        }
    }
    
    PROCESS
    {
        # Get existing Azure Automation Schedules where HourInterval is $Interval
        $AzureAutomationSchedules = Get-AzureAutomationSchedule -AutomationAccountName $AutomationAccount.AutomationAccountName | Where-Object {$_.HourInterval -eq $Interval}
        Write-Verbose "Found $($AzureAutomationSchedules.Count) Azure Automation Schedule(s) with same Hour Interval."

        # Set base for new Azure Automation Schedule start time (can not be before [now]+5min)
        $StartTime = ([Datetime]::Today).AddDays(+1)

        # Generate minute markers and concatenate description
        $MinuteMarkers = Foreach ($Minute in 0..59)
        {
            # Skip Azure Automation Schedules that already exists
            If ($Minute -notin $AzureAutomationSchedules.StartTime.Minute)
            {
                # Gather all valid minutes
                $Matches = @()
                If ($Minute -eq 0)
                {
                    # Join all values (Segment FriendlyName) on minute 0
                    $Matches = $Segments.Values -join ","
                }
                else
                {
                    foreach ($Key in $Segments.Keys)
                    {
                        If (($Minute/$Key -is [int]) -eq $true)
                        {
                            $Matches += $Segments.$Key
                        }
                    }
                }
                    
                # Create schedule if matches are found
                If ($Matches.Count -gt 0)
                {
                    $Properties = [ordered]@{
                        AutomationAccountName = $AutomationAccount.AutomationAccountName
                        HourInterval = $Interval
                        Name = "Every $Interval Hour(s) at minute $Minute"
                        StartTime = $StartTime.AddMinutes($Minute)
                        Description = $Matches -join ","
                    }
        
                    Try
                    {
                        New-AzureAutomationSchedule @Properties
                        Write-Verbose "Creted Azure Automation Schedule for ""Every $Interval Hour(s) at minute $Minute""."
                    }
                    Catch
                    {
                        $_
                    }
                }
            }
            else
            {
                Write-Verbose "Azure Automation Schedule for ""Every $Interval Hour(s) at minute $Minute"" already exists."
            }
        }
    }

    END {}
}