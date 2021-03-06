@{
    # Allowed global settings: cooldown, original, output, skipDownloaded
    # Local settings take precedence
    cooldown = 3
    original = $false
    skipDownloaded = $true
    All = [System.Collections.ArrayList]@( # Do not change this key name
        @{
            repo = @{
                url = "https://apt.procurs.us" # Repo URL
                suites = "iphoneos-arm64/1700" # Dist repo's suites
                components = "main" # Actually does pretty much nothing at all
            }
            output = "..\..\repo\procursus\iphoneos-arm64\1700" # Output directory, relative to main.ps1's root
            cooldown = 3 # Seconds of cooldown in-between downloads
            original = $false # Set to $true to not rename files
            auth = "" # Authentication file (JSON), relative to main.ps1's root
            dlpackage = @() # Empty array to download all packages
        }
        @{
            repo = @{
                url = "https://repo.chariz.com/"
                suites = ""
                components = ""
            }
            output = "E:\Documents\repo\chariz"
            cooldown = 3
            original = $false
            auth = "authentication\chariz.json"
            dlpackage = @("com.tr1fecta.akara")
        }
    )
}

