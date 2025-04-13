# Import required module
Import-Module ActiveDirectory

# User configurable parameters
param (
    [string]$CsvPath = ".\FakeNames.csv",
    [string]$BaseDomain = "DC=smartcore,DC=local",
    [string]$DefaultPassword = "Aa123456",
    [string]$EmailDomain = "SMARTCORE.LOCAL"
)

# Function to create username from first name and last name initial
function Get-FormattedUsername {
    param (
        [string]$FirstName,
        [string]$LastName
    )
    # Remove spaces and special characters, take first letter of last name
    $cleanFirstName = $FirstName.ToLower() -replace '[^a-zA-Z]', ''
    $lastNameInitial = $LastName.Substring(0,1).ToLower()
    return "$cleanFirstName$lastNameInitial"
}

# Function to determine OU path based on department and job title
function Get-OUPath {
    param (
        [string]$Department,
        [string]$JobTitle,
        [string]$DC
    )
    
    # Clean up department name
    $dept = $Department.Trim()
    
    # Fix department names and set OU paths
    switch -Wildcard ($dept) {
        "*Costumer*Service*" { 
            $dept = "Customer_Service"
            if ($JobTitle -match "Manager") {
                return "OU=Customer_Service_Manager,OU=Customer_Service,OU=Departments,$DC"
            }
            elseif ($JobTitle -match "Admin") {
                return "OU=Customer_Service_Admin,OU=Customer_Service,OU=Departments,$DC"
            }
            else {
                return "OU=Customer_Service_Users,OU=Customer_Service,OU=Departments,$DC"
            }
        }
        "HelpDesk" { 
            if ($JobTitle -match "Manager") {
                return "OU=HelpDesk_Manager,OU=HelpDesk,OU=IT,$DC"
            }
            else {
                return "OU=HelpDesk_Technicians,OU=HelpDesk,OU=IT,$DC"
            }
        }
        default {
            $dept = $dept -replace '\s+', '_'
            if ($JobTitle -match "Manager") {
                return "OU=${dept}_Manager,OU=$dept,OU=Departments,$DC"
            }
            elseif ($JobTitle -match "Admin") {
                return "OU=${dept}_Admin,OU=$dept,OU=Departments,$DC"
            }
            else {
                return "OU=${dept}_Users,OU=$dept,OU=Departments,$DC"
            }
        }
    }
}

# Check if CSV file exists
if (-not (Test-Path -Path $CsvPath)) {
    Write-Host "CSV file not found at path: $CsvPath" -ForegroundColor Red
    Write-Host "Please provide a valid path to the CSV file using the -CsvPath parameter." -ForegroundColor Yellow
    Write-Host "Example: .\ad-user-creation.ps1 -CsvPath 'C:\path\to\your\file.csv'" -ForegroundColor Yellow
    exit
}

# Import CSV file
$users = Import-Csv -Path $CsvPath -Encoding UTF8

# Create a log file in the same directory as the script
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$logPath = Join-Path -Path $scriptDir -ChildPath "CreatedUsers_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
New-Item -ItemType File -Path $logPath -Force | Out-Null

# Display start message
Write-Host "Starting user creation process for $($users.Count) users..." -ForegroundColor Cyan
Write-Host "CSV file: $CsvPath" -ForegroundColor Cyan
Write-Host "Domain structure: $BaseDomain" -ForegroundColor Cyan
Write-Host "Email domain: $EmailDomain" -ForegroundColor Cyan
Write-Host "This will create all users from the CSV file." -ForegroundColor Yellow
$confirmation = Read-Host "Do you want to proceed? (Y/N)"

if ($confirmation -ne "Y") {
    Write-Host "Operation cancelled by user." -ForegroundColor Yellow
    exit
}

$successCount = 0
$errorCount = 0

# Process each user
foreach ($user in $users) {
    try {
        # Generate username
        $username = Get-FormattedUsername -FirstName $user.FirstName -LastName $user.LastName
        
        # Generate email
        $email = "$username@$EmailDomain"
        
        # Get OU path based on department and job title
        $ouPath = Get-OUPath -Department $user.Department -JobTitle $user.Jobtitle -DC $BaseDomain
        
        Write-Host "`nCreating user: $($user.FirstName) $($user.LastName)" -ForegroundColor Cyan
        Write-Host "Username: $username" -ForegroundColor Cyan
        Write-Host "Department: $($user.Department)" -ForegroundColor Cyan
        Write-Host "Job Title: $($user.Jobtitle)" -ForegroundColor Cyan
        Write-Host "OU Path: $ouPath" -ForegroundColor Cyan
        
        # Create new user parameters
        $userParams = @{
            Name = "$($user.FirstName) $($user.LastName)"
            GivenName = $user.FirstName
            Surname = $user.LastName
            SamAccountName = $username
            UserPrincipalName = $email
            EmailAddress = $email
            Title = $user.Jobtitle
            Department = $user.Department
            Path = $ouPath
            Enabled = $true
            ChangePasswordAtLogon = $true
            AccountPassword = (ConvertTo-SecureString $DefaultPassword -AsPlainText -Force)
            StreetAddress = $user.StreetAddress
            City = $user.City
        }

        # Remove user if exists
        if (Get-ADUser -Filter "SamAccountName -eq '$username'") {
            Remove-ADUser -Identity $username -Confirm:$false
            Write-Host "Removed existing user: $username" -ForegroundColor Yellow
        }

        # Create the user
        New-ADUser @userParams

        # Set telephone number separately
        if (-not [string]::IsNullOrEmpty($user.TelephoneNumber)) {
            Set-ADUser -Identity $username -Replace @{
                telephoneNumber = $user.TelephoneNumber
            }
        }

        $successCount++
        $message = "Created user: $username ($($user.FirstName) $($user.LastName))"
        Write-Host $message -ForegroundColor Green
        Add-Content -Path $logPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - SUCCESS - $message"
    }
    catch {
        $errorCount++
        $message = "Error creating user $($user.FirstName) $($user.LastName): $($_.Exception.Message)"
        Write-Host $message -ForegroundColor Red
        Add-Content -Path $logPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - ERROR - $message"
        Add-Content -Path $logPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - DEBUG - Department: $($user.Department)"
        Add-Content -Path $logPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - DEBUG - Job Title: $($user.Jobtitle)"
        Add-Content -Path $logPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - DEBUG - Attempted OU path: $ouPath"
    }
}

# Display summary
Write-Host "`nUser creation process completed:" -ForegroundColor Cyan
Write-Host "Successfully created: $successCount users" -ForegroundColor Green
Write-Host "Failed to create: $errorCount users" -ForegroundColor Red
Write-Host "Log file has been saved to: $logPath" -ForegroundColor Cyan