# Import required module
Import-Module ActiveDirectory

# User configurable parameters
param (
    [string]$CsvPath = ".\FakeNames.csv"
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

# Check if CSV file exists
if (-not (Test-Path -Path $CsvPath)) {
    Write-Host "CSV file not found at path: $CsvPath" -ForegroundColor Red
    Write-Host "Please provide a valid path to the CSV file using the -CsvPath parameter." -ForegroundColor Yellow
    Write-Host "Example: .\ad-user-deletion.ps1 -CsvPath 'C:\path\to\your\file.csv'" -ForegroundColor Yellow
    exit
}

Write-Host "Reading users from: $CsvPath" -ForegroundColor Cyan

# Create a log file in the same directory as the script
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$logPath = Join-Path -Path $scriptDir -ChildPath "DeletedUsers_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
New-Item -ItemType File -Path $logPath -Force | Out-Null

try {
    # Import CSV file
    $users = Import-Csv -Path $CsvPath -Encoding UTF8
    Write-Host "Found $($users.Count) users in CSV file." -ForegroundColor Yellow

    # Ask for confirmation
    Write-Host "`nWARNING: This script will delete all users from the CSV file." -ForegroundColor Red
    Write-Host "Number of users to be deleted: $($users.Count)" -ForegroundColor Red
    $confirmation = Read-Host "Are you sure you want to proceed? (Y/N)"

    if ($confirmation -ne "Y") {
        Write-Host "Operation cancelled by user." -ForegroundColor Yellow
        exit
    }

    # Counter for tracking
    $deletedCount = 0
    $errorCount = 0
    $notFoundCount = 0

    # Process each user
    foreach ($user in $users) {
        try {
            # Generate username
            $username = Get-FormattedUsername -FirstName $user.FirstName -LastName $user.LastName
            
            Write-Host "Processing user: $username" -ForegroundColor Yellow
            
            # Check if user exists
            if (Get-ADUser -Filter "SamAccountName -eq '$username'") {
                # Get user details before deletion
                $userDetails = Get-ADUser -Identity $username -Properties *
                
                # Remove the user
                Remove-ADUser -Identity $username -Confirm:$false
                
                $deletedCount++
                $message = "Successfully deleted user: $username ($($user.FirstName) $($user.LastName))"
                Write-Host $message -ForegroundColor Green
                Add-Content -Path $logPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - SUCCESS - $message"
            }
            else {
                $notFoundCount++
                $message = "User not found: $username ($($user.FirstName) $($user.LastName))"
                Write-Host $message -ForegroundColor Yellow
                Add-Content -Path $logPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - SKIPPED - $message"
            }
        }
        catch {
            $errorCount++
            $message = "Error deleting user $username ($($user.FirstName) $($user.LastName)): $($_.Exception.Message)"
            Write-Host $message -ForegroundColor Red
            Add-Content -Path $logPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - ERROR - $message"
        }
    }

    # Display summary
    Write-Host "`nDeletion process completed:" -ForegroundColor Cyan
    Write-Host "Successfully deleted: $deletedCount users" -ForegroundColor Green
    Write-Host "Not found: $notFoundCount users" -ForegroundColor Yellow
    Write-Host "Errors encountered: $errorCount users" -ForegroundColor Red
    Write-Host "Details can be found in the log file: $logPath" -ForegroundColor Cyan

}
catch {
    Write-Host "Critical error: $($_.Exception.Message)" -ForegroundColor Red
    Add-Content -Path $logPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - CRITICAL - $($_.Exception.Message)"
}