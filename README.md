# AD-Users-Management
PowerShell scripts for Active Directory user management.
This repository contains PowerShell scripts for managing users in Active Directory. The scripts allow for the creation and deletion of users from a CSV file.

## Scripts

### ad-user-creation.PS1
Script for creating new users in Active Directory from a CSV file.

**Features:**
- Creates username from first name + first letter of last name
- Places users in appropriate OUs based on department and job title
- Sets properties like email, department, address, etc.
- Sets initial password with requirement to change at first login
- Creates detailed log file

**Customizable Parameters:**
- `CsvPath` - Path to the CSV file (default: ".\FakeNames.csv")
- `BaseDomain` - Base domain structure (default: "DC=smartcore,DC=local")
- `DefaultPassword` - Initial password (default: "Aa123456")
- `EmailDomain` - Domain for email addresses (default: "SMARTCORE.LOCAL")

### ad-user-deletion.PS1
Script for deleting users from Active Directory based on a CSV file.

**Features:**
- Uses the same method for username creation
- Confirmation before deletion
- Tracks deleted users, not found users, and errors
- Creates detailed log file

**Customizable Parameters:**
- `CsvPath` - Path to the CSV file (default: ".\FakeNames.csv")

## OU Structure
The scripts expect an OU structure in the following format:
```
DC=smartcore,DC=local
├── OU=Departments
│   ├── OU=[Department]
│   │   ├── OU=[Department]_Manager
│   │   ├── OU=[Department]_Admin
│   │   └── OU=[Department]_Users
└── OU=IT
    └── OU=HelpDesk
        ├── OU=HelpDesk_Manager
        └── OU=HelpDesk_Technicians
```

## Requirements
- Windows Server with Active Directory
- PowerShell 5.1 or higher
- Active Directory PowerShell module

## Usage
### Preparing the CSV File
Prepare a CSV file with the following columns:
- FirstName
- LastName
- Department
- Jobtitle
- TelephoneNumber
- StreetAddress
- City

### Creating Users
```powershell
# Using default path (.\FakeNames.csv)
.\ad-user-creation.ps1

# Using specific CSV file
.\ad-user-creation.ps1 -CsvPath "C:\Path\To\Your\File.csv"

# Using all parameters
.\ad-user-creation.ps1 -CsvPath "C:\Path\To\Your\File.csv" -BaseDomain "DC=company,DC=local" -DefaultPassword "P@ssw0rd123" -EmailDomain "company.com"
```

### Deleting Users
```powershell
# Using default path (.\FakeNames.csv)
.\ad-user-deletion.ps1

# Using specific CSV file
.\ad-user-deletion.ps1 -CsvPath "C:\Path\To\Your\File.csv"
```

## Security Notes
- It is recommended to change the default password before using in a production environment
- Make sure access permissions to script files are limited to administrators only
- Store the CSV file in a secure location

## Support and Questions
If you have questions or suggestions for improvement, don't hesitate to create a new Issue in this repository.
