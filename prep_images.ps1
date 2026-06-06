[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$src = "C:\Users\Bobi\Documents\Projects\PhotographyPortfolio\Portfolio-20260311_152313"
$dest = "C:\Users\Bobi\Documents\Projects\PhotographyPortfolio\images"

# Normalize source path to avoid backslash issues when calculating relative paths
$srcPath = $src.TrimEnd('\')

# --- CONFIGURATION ---
$watermark = "© Борислав Дочев"

# Folders to completely ignore
$excludeDirs = @("retired", "unsorted", "papaya")

# Profiles based on top-level subfolders. 
# If an image is in "\people\...", it uses the 'people' profile.
# If a folder isn't listed here, it falls back to 'default'.
$profiles = @{
    "default"   = @{ thumbResize = "500>"; thumbQuality = 90; fullResize = "2000>"; fullQuality = 75 }
    "people"    = @{ thumbResize = "800>"; thumbQuality = 98; fullResize = "2000>"; fullQuality = 80 }
    "events"    = @{ thumbResize = "600>"; thumbQuality = 90; fullResize = "2000>"; fullQuality = 75 }
    "main-page" = @{ thumbResize = "800>"; thumbQuality = 95; fullResize = "2500>"; fullQuality = 85 }
}

# (Optional) Keep specific files strictly High Quality regardless of their folder
$highQualityOverrideList = @(
    "hjIMG_0753_01.jpg", "hjIMG_0822.jpg", "hjIMG_1041.jpg" # Add the rest here if still needed
)
# ---------------------

# Get all valid image files recursively
$files = Get-ChildItem -Path $srcPath -Recurse -File | Where-Object { 
    $_.Extension -match '\.(jpg|heic|png)$' 
}

foreach ($file in $files) {
    # 1. Calculate relative directory path to mirror the structure
    $relDir = ""
    if ($file.DirectoryName.Length -gt $srcPath.Length) {
        $relDir = $file.DirectoryName.Substring($srcPath.Length).Trim('\')
    }

    # 2. Check exclusions
    $skip = $false
    foreach ($ex in $excludeDirs) {
        # Check if the relative path contains the excluded directory
        if ("\$relDir\" -match "\\$ex\\") { 
            $skip = $true
            break 
        }
    }
    if ($skip) { continue }

    # 3. Determine which configuration profile to use
    $topFolder = ($relDir -split '\\')[0]
    $config = $profiles["default"] # Fallback

    if ($profiles.ContainsKey($topFolder)) {
        $config = $profiles[$topFolder]
    }

    # Apply file-specific override if it's in your hardcoded list
    if ($file.Name -in $highQualityOverrideList) {
        $config = $profiles["people"] # Treat explicit overrides with the highest quality profile
    }

    # 4. Create matching destination directories
    $destThumbDir = Join-Path "$dest\thumb" $relDir
    $destFullDir  = Join-Path "$dest\full" $relDir

    if (-not (Test-Path $destThumbDir)) { New-Item -ItemType Directory -Path $destThumbDir -Force | Out-Null }
    if (-not (Test-Path $destFullDir))  { New-Item -ItemType Directory -Path $destFullDir -Force | Out-Null }

    $thumbPath = Join-Path $destThumbDir "$($file.BaseName).webp"
    $fullPath  = Join-Path $destFullDir "$($file.BaseName).webp"

    # --- 5. Process Thumbnail ---
    if (-not (Test-Path $thumbPath)) {
        Write-Host "Generating thumbnail for: $($file.Name) [Profile: $(if($topFolder){$topFolder}else{'default'})]" -ForegroundColor Cyan
        magick "$($file.FullName)" -auto-orient -resize $($config.thumbResize) -quality $($config.thumbQuality) $thumbPath
    } else {
        Write-Host "Skipping thumbnail (exists): $($file.Name)" -ForegroundColor DarkGray
    }

    # --- 6. Process Full Size + Watermark ---
    if (-not (Test-Path $fullPath)) {
        Write-Host "Generating full size for: $($file.Name)" -ForegroundColor Green
        
        magick "$($file.FullName)" -auto-orient -resize $($config.fullResize) -quality $($config.fullQuality) `
            -fill "white" -background "none" -size "%[fx:w*0.12]x" label:"$watermark" `
            -bordercolor "#00000080" -border 12x6 `
            -gravity southeast -geometry +15+15 -composite $fullPath
    } else {
        Write-Host "Skipping full size (exists): $($file.Name)" -ForegroundColor DarkGray
    }
}