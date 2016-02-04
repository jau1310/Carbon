# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

& (Join-Path -Path $PSScriptRoot -ChildPath '..\Initialize-CarbonDscResource.ps1' -Resolve)

function Get-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$Name
	)

    Set-StrictMode -Version 'Latest'

    Write-Debug ('GetScript - Group Name: {0}' -f $Name)

    $groupObj = (Get-Group -Name $Name -ErrorAction Ignore)

    $Ensure = $null
    if ($groupObj)
    {
        $Ensure = 'Present'
    }
    else
    {
        $Ensure = 'Absent'
    }

    $returnValue = @{
		Name = $Name
		Ensure = $Ensure
		Description = $groupObj.Description
		Members = $groupObj.Members
	}

    Write-Output $returnValue
}

function Set-TargetResource
{
    <#
    .SYNOPSIS
    DSC resource for configuring local Windows groups.

    .DESCRIPTION
    The `Carbon_Group` resource installs and uninstalls groups. It also adds members to existing groups. 
    
    The group is installed when `Ensure` is set to `Present`. If `Members` has a value, they are converted to Windows users/group accounts and added to the group. Other group members are left in the group. Because DSC resources run under the LCM which runs as `System`, local system accounts must have access to the directories where both new and existing member accounts can be found.

    The group is removed when `Ensure` is set to `Absent`. When removing a group, the `Members` property is ignored.

    .LINK
    Add-GroupMember

    .LINK
    Install-Group

    .LINK
    Remove-GroupMember

    .LINK
    Test-Group

    .LINK
    Uninstall-Group

    .EXAMPLE
    >
    Demonstrates how to install a group and add members to it.

        Carbon_Group 'CreateFirstOrder'
        {
            Name = 'FirstOrder';
            Description = 'On to victory!';
            Ensure = 'Present';
            Members = @( 'FO\SupremeLeaderSnope', 'FO\KRen' );
        }

    .EXAMPLE
    >
    Demonstrates how to uninstall a group.

        Carbon_Group 'RemoveRepublic
        {
            Name = 'Republic';
            Ensure = 'Absent';
        }

    #>
	[CmdletBinding()]
	param
	(
		[parameter(Mandatory=$true)]
		[string]
        # The name of the group.
		$Name,

		[string]
        # A description of the group. Only used when adding/updating a group (i.e. when `Ensure` is `Present`).
		$Description,

		[ValidateSet("Present","Absent")]
		[string]
        # Should be either `Present` or `Absent`. If set to `Present`, a group is configured and membership configured. If set to `Absent`, the group is removed.
		$Ensure,

		[string[]]
        # The membership of the group. Only used when adding/updating a group (i.e. when `Ensure` is `Present`).
		$Members
	)

    Set-StrictMode -Version 'Latest'

    Write-Debug ('SetScript - Group Name: {0}' -f $Name)

    if ($Ensure -eq 'Present')
    {
        if ($Members)
        {
            Write-Debug ('Ensure is ''{0}'', installing group {1}' -f $Ensure,$Name)
            Write-Debug ('Members to be added:')
            ($Members | Format-Table -AutoSize -Wrap | Out-String | Write-Debug)

            Install-Group -Name $Name -Description $Description -Member $Members
        }
        else
        {
            Write-Debug ('Ensure is ''{0}'', installing group {1}' -f $Ensure,$Name)
            Install-Group -Name $Name -Description $Description
        }
    }
    else
    {
        Write-Debug ('Removing group {0}' -f $Name)
        Uninstall-Group -Name $Name
    }
}

function Test-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Boolean])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$Name,

		[System.String]
		$Description,

		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure = "Present",

		[System.String[]]
		$Members
	)

    Set-StrictMode -Version 'Latest'

    Write-Debug ('TestScript - Group Name: {0}' -f $Name)

    $result = Test-Group -Name $Name

    if (-not $Members)
    {
        Write-Debug ('Group [{0}] exists' -f $Name)
    }
    elseif($result -and $Members)
    {
        $rawMembers = (Get-Group -Name $Name).Members

        Write-Debug ('Current members of group {0}' -f $Name)
        # needs to be in parens otherwise get 'Undefined DSC resource Write-Verbose. Use Import-DSCResource to import the resource'
        ($rawMembers | Select SamAccountName,ContextType,@{Name="Domain";Expression={($_.Context.Name)}} | Format-Table -AutoSize -Wrap | Out-String | Write-Debug)

        $result = $true
        foreach ($member in $Members)
        {
            try
            {
                Write-Debug ('User Resolution - Start:    {0}' -f $member)
                $secPrincipal = Resolve-Identity -Name $member -ErrorAction Stop
            }
            catch
            {
                Write-Warning -Message ('User Resolution - Failed: {0}' -f $PSItem.Exception.Message)
                continue
            }

            Write-Debug ('User Resolution - Resolved: {0}' -f $member)

            $isInGroup = $false
            foreach ($currentMember in $rawMembers)
            {
                Write-Debug ('Comparing - {0} ({1}) --> {2} ({3})' -f $secPrincipal,$secPrincipal.Sid,$currentMember,$currentMember.Sid)
                if ($secPrincipal.Sid -eq $currentMember.Sid)
                {
                    Write-Debug ('Comparing - Match found for user: {0}' -f $secPrincipal)
                    $isInGroup = $true
                    break
                }
            }

            if (-not $isInGroup)
            {
                Write-Verbose (' [{0}] User {1} not a member.' -f $Name,$member)
                $result = $false
            }
        }

        if( $result )
        {
            Write-Verbose (' [{0}] All members present.' -f $Name)
        }
    }

    # The above code assumes Ensure = Present. If it's Absent, then just switch the results around
    If ($Ensure -eq 'Absent')
    {
        if ($result -eq $true)
        {
            $result = $false
        }
        else
        {
            $result = $true
        }
    }

    return $result
}

Export-ModuleMember -Function *-TargetResource

