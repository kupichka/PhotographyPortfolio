[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$src = "C:\Users\Bobi\Documents\Projects\PhotographyPortfolio\Portfolio-20260311_152313"
$dest = "C:\Users\Bobi\Documents\Projects\PhotographyPortfolio\images"

# --- CONFIGURATION ---
# Watermark text
$watermark = "© Борислав Дочев"

# List of files that need higher quality thumbnails (include extensions, e.g., 'P1025004.jpg')
$highQualityList = @(
    "hjIMG_0753_01.jpg",
    "hjIMG_0768_01.jpg",
    "hjIMG_0822.jpg",
    "hjIMG_1041.jpg",
    "hjIMG_0737.jpg",
    "hjIMG_0793.jpg",
    "hjIMG_0815.jpg",
    "hjIMG_1104.jpg",
    "hjIMG_0741.jpg",
    "hjIMG_0779.jpg",
    "hjIMG_1109.jpg",
    "hjIMG_0941.jpg",
    "hjIMG_0912.jpg",
    "hjIMG_0930.jpg",
    "hjIMG_1022.jpg",
    "hjIMG_1065.jpg",
	"people-nikola-nikolov.png",
    "people-asen-kirov.jpg"
)

# Standard vs High Quality Thumbnail Settings
$stdThumbResize  = "500>"
$stdThumbQuality = 90

$hqThumbResize   = "800>"  # Slightly larger resolution for crisp details if needed
$hqThumbQuality  = 98     # Maximum visual fidelity, minimal compression
# ---------------------

# Create output directories if they don't exist
mkdir "$dest\thumb" -Force | Out-Null
mkdir "$dest\full"  -Force | Out-Null

# Get all .jpg and .heic files from the source directory
$files = Get-ChildItem -Path $src -File | Where-Object { $_.Extension -in '.jpg', '.heic', '.png' }

foreach ($file in $files) {
    $baseName = $file.BaseName
    
    # Define expected output paths
    $thumbPath = Join-Path "$dest\thumb" "$baseName.webp"
    $fullPath  = Join-Path "$dest\full" "$baseName.webp"

    # --- 1. Process Thumbnail ---
    if (-not (Test-Path $thumbPath)) {
        # Check if this file is designated for High Quality
        if ($file.Name -in $highQualityList) {
            Write-Host "Generating HIGH QUALITY thumbnail for: $($file.Name)" -ForegroundColor Magenta
            magick "$($file.FullName)" -auto-orient -resize $hqThumbResize -quality $hqThumbQuality $thumbPath
        } else {
            Write-Host "Generating standard thumbnail for: $($file.Name)" -ForegroundColor Cyan
            magick "$($file.FullName)" -auto-orient -resize $stdThumbResize -quality $stdThumbQuality $thumbPath
        }
    } else {
        Write-Host "Skipping thumbnail (already exists): $($file.Name)" -ForegroundColor DarkGray
    }

    # --- 2. Process Full Size + Fixed Watermark ---
    if (-not (Test-Path $fullPath)) {
        Write-Host "Generating full size for: $($file.Name)" -ForegroundColor Green
        
        # Uses -background "none" and transfers the colored rectangle entirely to -border 
        magick "$($file.FullName)" -auto-orient -resize "2000>" -quality 75 `
            -fill "white" -background "none" -size "%[fx:w*0.12]x" label:"$watermark" `
            -bordercolor "#00000080" -border 12x6 `
            -gravity southeast -geometry +15+15 -composite $fullPath
    } else {
        Write-Host "Skipping full size (already exists): $($file.Name)" -ForegroundColor DarkGray
    }
}