$ErrorActionPreference = "Stop"

$Repo = "HashShin/hashcode"
$Binary = "hashcode"

function Write-Info { param($Message) Write-Host "=> $Message" -ForegroundColor Cyan }
function Write-Success { param($Message) Write-Host "OK $Message" -ForegroundColor Green }
function Write-WarnMessage { param($Message) Write-Host "!  $Message" -ForegroundColor Yellow }
function Stop-Install {
    param($Message)
    Write-Host "ERROR: $Message" -ForegroundColor Red
    exit 1
}

$Arch = switch ($env:PROCESSOR_ARCHITECTURE) {
    "AMD64" { "amd64" }
    "ARM64" { "arm64" }
    default { Stop-Install "Unsupported architecture: $env:PROCESSOR_ARCHITECTURE" }
}

Write-Info "Fetching the latest release..."
try {
    $Release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest"
}
catch {
    Stop-Install "Unable to fetch release information: $($_.Exception.Message)"
}

$Tag = $Release.tag_name
if (-not $Tag) {
    Stop-Install "The latest release has no tag."
}

$Filename = "$Binary-windows-$Arch.exe"
$Asset = $Release.assets | Where-Object { $_.name -eq $Filename } | Select-Object -First 1
if (-not $Asset) {
    Stop-Install "Release $Tag does not contain $Filename."
}

$TempDirectory = Join-Path ([System.IO.Path]::GetTempPath()) "hashcode-$([guid]::NewGuid())"
$TempBinary = Join-Path $TempDirectory "$Binary.exe"
New-Item -ItemType Directory -Path $TempDirectory -Force | Out-Null

try {
    Write-Info "Downloading $Binary $Tag for windows/$Arch..."
    $ProgressPreference = "Continue"
    Invoke-WebRequest -Uri $Asset.browser_download_url -OutFile $TempBinary -UseBasicParsing

    $ChecksumAsset = $Release.assets |
        Where-Object { $_.name -eq "checksums.txt" } |
        Select-Object -First 1

    if ($ChecksumAsset) {
        $ChecksumFile = Join-Path $TempDirectory "checksums.txt"
        Invoke-WebRequest -Uri $ChecksumAsset.browser_download_url -OutFile $ChecksumFile -UseBasicParsing
        $ChecksumLine = Get-Content $ChecksumFile |
            Where-Object { $_ -match "(^|\s)\*?$([regex]::Escape($Filename))$" } |
            Select-Object -First 1

        if ($ChecksumLine -and $ChecksumLine -match "^([a-fA-F0-9]{64})") {
            $Expected = $Matches[1].ToLowerInvariant()
            $Actual = (Get-FileHash -Path $TempBinary -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($Actual -ne $Expected) {
                Stop-Install "Checksum verification failed."
            }
            Write-Success "Checksum verified."
        }
        else {
            Write-WarnMessage "No checksum entry found for $Filename."
        }
    }
    else {
        Write-WarnMessage "This release has no checksums.txt; continuing without verification."
    }

    $InstallDirectory = Join-Path $env:LOCALAPPDATA "hashcode"
    New-Item -ItemType Directory -Path $InstallDirectory -Force | Out-Null
    Copy-Item -Path $TempBinary -Destination (Join-Path $InstallDirectory "$Binary.exe") -Force
    Write-Success "Installed $Binary $Tag to $InstallDirectory\$Binary.exe"

    $UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $PathEntries = @($UserPath -split ";" | Where-Object { $_ })
    if ($PathEntries -notcontains $InstallDirectory) {
        $UpdatedPath = (($PathEntries + $InstallDirectory) -join ";")
        [Environment]::SetEnvironmentVariable("Path", $UpdatedPath, "User")
        Write-WarnMessage "Added $InstallDirectory to PATH; restart your terminal."
    }

    Write-Host ""
    Write-Host "Done! Run: " -NoNewline
    Write-Host $Binary -ForegroundColor Cyan
}
finally {
    Remove-Item -Path $TempDirectory -Recurse -Force -ErrorAction SilentlyContinue
}
