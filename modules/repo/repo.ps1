function Get-RepoPackage {
    param (
        [Parameter(Mandatory, Position=0)]
        [hashtable]$repo
    )
    if ($repo.installer) {
        Write-Host "==> Attempting to download Packages.xml (Installer repo)" -ForegroundColor Blue
        Get-InstallerRepoPackage $repo
    }
    else {
        Get-DebRepoPackage $repo
    }
}

function ConvertFrom-Package {
    param (
        [Parameter(Mandatory, Position=0)]
        [string]$pkgf
    )
    if ($repo.installer) {
        $output = ConvertFrom-InstallerPackage $pkgf
    }
    else {
        $output = ConvertFrom-DebPackage $pkgf
    }
    return $output
}

<#
.SYNOPSIS
    Download an entire Debian repository, or parts of it.
.PARAMETER repo
    A hashtable with 3 keys: url, suites and parameters.
    If downloading a flat repo, suites and parameters can be null/empty.
.PARAMETER output
    Folder to save the downloaded repo, can be absolute or relative paths.
.PARAMETER cooldown
    Time to wait between each request to the repo, avoiding rate limits.
.PARAMETER original
    Save files as their original name instead of renaming to
    PACKAGENAME-VERSION.deb
.PARAMETER skipDownloaded
    Skip files that already exists in $output.
.PARAMETER dlpackage
    Download packages only from this list; all others are ignored.
#>
function Get-Repo($repo, $output, $cooldown = 5, $original = $false, $auth, $skipDownloaded = $true, $dlpackage = @()) {
    if ($null -eq $output) {
        $output = ".\output\{0}" -f ($repo.url -replace '(^\w+:|^)\/\/','')
    }
    $repo.url = Format-Url $repo.url

    # Workaround as ternary operators are not available until PowerShell v7
    # Instead of <condition> ? <true> : <false>, we take advantage of $true being 1 and $false being 0, to make it index arrays:
    # (<false>, <true>)[<condition>]
    $repo.installer = ((Test-InstallerRepo $repo), $repo.installer)[$repo.ContainsKey('installer')]
    $output = Resolve-PathForced $output
    $specific_package = $dlpackage.Count -gt 0

    if ((![string]::IsNullOrWhiteSpace($auth)) -and (Test-Path $auth)) {
        $repo.endpoint = Get-PaymentEndpoint $repo
        $authinfo = Get-AuthenticationData $repo.endpoint $auth
    }


    try {
        Get-RepoPackage $repo
    }
    catch {
        $exc = $Error[0].Exception.Message
        throw $exc
    }

    Write-Host "==> Starting downloads" -ForegroundColor Blue
    $pkgc = ConvertFrom-Package Packages
    $length =  $pkgc.link.Length
    $mentioned_nondls = [System.Collections.ArrayList]@("4d2b0bad-0021-44ed-a8e4-c50ae895dd99")
    for ($i = 0; $i -lt $length; $i++) {
        $curr = $i + 1
        $prepend = "($curr/$length)"
        $requestmade = $false

        if ($mentioned_nondls.Contains($pkgc[$i].name)) {
            continue
        }
        if ($specific_package -and !($dlpackage -contains $pkgc[$i].name)) {
            Write-Verbose ("Skipping unspecified package " + $pkgc[$i].name)
            [void]$mentioned_nondls.Add($pkgc[$i].name)
            continue
        }

        if ($original) {
            $filename = [System.IO.Path]::GetFileName($pkgc[$i].link)
        }
        else {
            $filename = $pkgc[$i].name + "-" + $pkgc[$i].version + [System.IO.Path]::GetExtension($pkgc[$i].link)
        }
        $filename = Rename-InvalidFileNameChar $filename -Replacement "_"
        $destination = Join-Path -Path $output -ChildPath $pkgc[$i].name -AdditionalChildPath $filename

        if ($skipDownloaded -and (Test-Path $destination)) {
            Write-Verbose ("Skipping downloaded package {0}" -f $filename)
            continue
        }

        try {
            if ($pkgc[$i].tag -and ($pkgc[$i].tag -Match "cydia::commercial")) {
                if ($authinfo.authstatus) {
                    if ($authinfo.purchased -contains $pkgc[$i].name) {
                        $authinfo.authtable.version = $pkgc[$i].version
                        $authinfo.authtable.repo = $repo.url
                        $requestmade = $true
                        $dllink = (Invoke-RestMethod -Method Post -Body $authinfo.authtable -Uri ($repo.endpoint + 'package/' + $namesList[$i] + '/authorize_download')).url
                    }
                    else {
                        [void]$mentioned_nondls.Add($pkgc[$i].name)
                        throw "Skipping unpurchased package."
                    }
                }
                else {
                    [void]$mentioned_nondls.Add($pkgc[$i].name)
                    throw 'Paid package but no authentication found.'
                }
            }
            else {
                $dllink = (($repo.url + $pkgc[$i].link), $pkgc[$i].link)[$repo.installer]
            }

            if (!(Test-Path (Join-Path $output $pkgc[$i].name))) {
                mkdir (Join-Path $output $pkgc[$i].name) > $null
            }
            Write-Verbose "Download link: $dllink"
            Write-Verbose ("Saving to: {0}" -f $destination)
            $requestmade = $true
            dl $dllink $destination "" $true $prepend
        }
        catch {
            Write-Color ("$prepend Download for $filename failed: {0}" -f $Error[0].Exception.Message) -color Red
            if (!$requestmade) {continue}
        }
        # Skip cooldown for last package
        if ($i -ne ($length - 1)) {Start-Sleep -Seconds ([double]$cooldown)}
    }
}