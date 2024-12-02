@{

    # Script module or binary module file associated with this manifest.
    RootModule = 'Volvo4evcc.psm1'
    
    # Version number of this module.
    ModuleVersion = '1.10'
    
    # ID used to uniquely identify this module
    GUID = '50047ffd-8482-4a42-94f3-52bbf7515d93'
    
    # Author of this module
    Author = 'Martijn van Geffen'
    
    # Company or vendor of this module
    CompanyName = '13TH Division'
    
    # Copyright statement for this module
    Copyright = '(c) 2024 13TH Division. All rights reserved.'
    
    # Description of the functionality provided by this module
    Description = 'Volvo services for EVCC integration'
    
    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '7.4'
    
    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        'Set-VolvoAuthentication'
        'Start-Volvo4Evcc'
    )
    
    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{
    
        PSData = @{
    
            # Tags applied to this module. These help with module discovery in online galleries.
            # Tags = @()
    
            # A URL to the license for this module.
            # LicenseUri = ''
    
            # A URL to the main website for this project.
            # ProjectUri = ''
    
            # A URL to an icon representing this module.
            # IconUri = ''
    
            # ReleaseNotes of this module
            # ReleaseNotes = ''
    
        } # End of PSData hashtable
    
    } # End of PrivateData hashtable
    }
    
    