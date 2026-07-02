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
    "default"   = @{ widths = @(120, 400, 800, 1200); quality = 75; fullResize = "2000>"; fullQuality = 75 }
    "people"    = @{ widths = @(120, 400, 800, 1200); quality = 75; fullResize = "2000>"; fullQuality = 80 }
    "events"    = @{ widths = @(120, 400, 800, 1200); quality = 75; fullResize = "2000>"; fullQuality = 75 }
    "main-page" = @{ widths = @(120, 400, 800, 1200); quality = 83; fullResize = "2500>"; fullQuality = 85 }
}

# (Optional) Keep specific files strictly High Quality regardless of their folder
$highQualityOverrideList = @(

)
# ---------------------

# Get all valid image files recursively
$files = Get-ChildItem -Path $srcPath -Recurse -File | Where-Object { 
    $_.Extension -match '\.(jpg|heic|png)$' 
}

# --- MAIN PAGE THUMBNAIL SHAPE DEFINITIONS ---
# These are the actual rendered box sizes for the gallery tiles,
# including the 10px gap between joined cells where applicable.
$mainPageThumbShapes = @{
    "1x1" = @{ w = 220; h = 180 }
    "1x2" = @{ w = 220; h = 370 }  # 180 + 180 + 10
    "2x1" = @{ w = 450; h = 180 }  # 220 + 220 + 10
    "2x2" = @{ w = 450; h = 370 }  # 220 + 220 + 10, 180 + 180 + 10
}

function New-CroppedWebpThumb {
    param(
        [string]$InputFile,
        [string]$OutputFile,
        [int]$TargetW,
        [int]$TargetH,
        [int]$Quality
    )

    & magick $InputFile -auto-orient `
        -resize "${TargetW}x${TargetH}^" `
        -gravity center -extent "${TargetW}x${TargetH}" `
        -quality $Quality `
        $OutputFile
}

$specialThumbShapeList = @(
	"events/2026_05_15/IMG_0726_01",
	"events/2026_05_15/IMG_0731",
	"events/2026_05_15/IMG_0753_01",
	"events/2026_05_15/IMG_0768_01",
	"events/2026_05_15/IMG_0779",
	"events/2026_05_15/IMG_0815",
	"events/2026_05_15/IMG_0875",
	"events/2026_05_15/IMG_1022",
	"events/2026_05_15/IMG_1141",
	"events/2026_05_15/IMG_1041",
	"events/2026_03_29/IMG_0140_02"
);


foreach ($file in $files) {
    # 1. Calculate relative directory path to mirror the structure
    $relDir = ""
    if ($file.DirectoryName.Length -gt $srcPath.Length) {
        $relDir = $file.DirectoryName.Substring($srcPath.Length).Trim('\')
    }
	$relKey = if ($relDir) {
		(($relDir -replace '\\','/') + "/$($file.BaseName)")
	} else {
		$file.BaseName
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

	# --- 5. Process Thumbnail(s) ---
	# Special logic only for /main-page/ images:
	# generate 1x1, 1x2, 2x1, 2x2 crops with the same responsive widths.
	$inMainPage = ($relDir -match '(^|\\)main-page(\\|$)')
	$needsShapeThumbs = $specialThumbShapeList -contains $relKey
	if ($needsShapeThumbs) {
		Write-Host "SPECIAL THUMBS ENABLED: $relKey" -ForegroundColor Yellow
	}

	# Old behavior for everything outside main-page
	foreach ($w in $config.widths) {
		$thumbPath = Join-Path $destThumbDir "$($file.BaseName)-${w}w.webp"

		if (-not (Test-Path $thumbPath)) {
			Write-Host "Generating ${w}w thumbnail for: $($file.Name) [Profile: $(if($topFolder){$topFolder}else{'default'})]" -ForegroundColor Cyan
			& magick "$($file.FullName)" -auto-orient -resize "${w}>" -quality $($config.quality) $thumbPath
		} else {
			Write-Host "Skipping ${w}w thumbnail (exists): $($file.Name)" -ForegroundColor DarkGray
		}
	}
	if ($inMainPage -or $needsShapeThumbs) {
		foreach ($shapeName in @("1x1", "1x2", "2x1", "2x2")) {
			$shape = $mainPageThumbShapes[$shapeName]

			foreach ($w in $config.widths) {
				# Keep the file naming width-based, but preserve the shape ratio.
				# Example: 400w -> shape-scaled crop that keeps the same aspect ratio.
				$scale = $w / 400.0
				$tw = [math]::Round($shape.w * $scale)
				$th = [math]::Round($shape.h * $scale)

				$thumbPath = Join-Path $destThumbDir "$($file.BaseName)-${shapeName}-${w}w.webp"

				if (-not (Test-Path $thumbPath)) {
					Write-Host "Generating ${shapeName} ${w}w thumbnail for: $($file.Name) [Profile: $(if($topFolder){$topFolder}else{'default'})]" -ForegroundColor Cyan
					New-CroppedWebpThumb -InputFile $file.FullName -OutputFile $thumbPath -TargetW $tw -TargetH $th -Quality $config.quality
				} else {
					Write-Host "Skipping ${shapeName} ${w}w thumbnail (exists): $($file.Name)" -ForegroundColor DarkGray
				}
			}
		}
	}

    # --- 6. Process Full Size + Watermark ---
    if (-not (Test-Path $fullPath)) {
        Write-Host "Generating full size for: $($file.Name)" -ForegroundColor Green
        
        magick "$($file.FullName)" `
			-auto-orient `
			-resize $($config.fullResize) `
			"(" `
				-background none `
				-fill white `
				-size "%[fx:w*0.12]x" `
				label:"$watermark" `
				-bordercolor "#00000080" `
				-border 12x6 `
			")" `
			-gravity southeast `
			-geometry +15+15 `
			-composite `
			-quality $($config.fullQuality) `
			$fullPath
    } else {
        Write-Host "Skipping full size (exists): $($file.Name)" -ForegroundColor DarkGray
    }
}