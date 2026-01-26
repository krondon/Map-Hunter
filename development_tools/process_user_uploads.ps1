Add-Type -AssemblyName System.Drawing

function Crop-Image {
    param(
        [string]$sourcePath,
        [string]$targetPath,
        [int]$x,
        [int]$y,
        [int]$width,
        [int]$height
    )
    
    if (!(Test-Path $sourcePath)) {
        Write-Host "File not found: $sourcePath"
        return
    }

    $sourceImg = [System.Drawing.Bitmap]::FromFile($sourcePath)
    $targetImg = New-Object System.Drawing.Bitmap($width, $height)
    $graphics = [System.Drawing.Graphics]::FromImage($targetImg)
    
    # Preserve transparency
    $graphics.Clear([System.Drawing.Color]::Transparent)
    
    $destRect = New-Object System.Drawing.Rectangle(0, 0, $width, $height)
    $srcRect = New-Object System.Drawing.Rectangle($x, $y, $width, $height)
    
    $graphics.DrawImage($sourceImg, $destRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
    
    $targetImg.Save($targetPath, [System.Drawing.Imaging.ImageFormat]::Png)
    
    $graphics.Dispose()
    $targetImg.Dispose()
    $sourceImg.Dispose()
    
    Write-Host "Created: $targetPath"
}

$avatarDir = "c:\Users\natac\Desktop\Busqueda_del_tesoro\Juego_QR\assets\images\avatars"
if (!(Test-Path $avatarDir)) { New-Item -ItemType Directory -Path $avatarDir }

# Paths provided by user uploads
# Note: Ensure the GUIDs match exactly what is in the metadata
$maleSource = "C:\Users\natac\.gemini\antigravity\brain\2172836a-2969-42d0-9ccc-76316eed3889\uploaded_media_1_1769366798667.png"
$femaleSource = "C:\Users\natac\.gemini\antigravity\brain\2172836a-2969-42d0-9ccc-76316eed3889\uploaded_media_0_1769366798667.png"

# We assume standard 2x2 grid. 
# If image is 1024x1024, quadrants are 512x512.
# We will assume 512x512 for all to be safe and include everything.

# --- MALES ---
Crop-Image $maleSource "$avatarDir\explorer_m.png" 0   0   512 512
Crop-Image $maleSource "$avatarDir\hacker_m.png"   512 0   512 512
Crop-Image $maleSource "$avatarDir\warrior_m.png"  0   512 512 500  # Slight crop at bottom if needed, but 500 is safe
Crop-Image $maleSource "$avatarDir\spec_m.png"     512 512 512 500

# --- FEMALES ---
Crop-Image $femaleSource "$avatarDir\explorer_f.png" 0   0   512 512
Crop-Image $femaleSource "$avatarDir\hacker_f.png"   512 0   512 512
Crop-Image $femaleSource "$avatarDir\warrior_f.png"  0   512 512 500
Crop-Image $femaleSource "$avatarDir\spec_f.png"     512 512 512 500

Write-Host "Avatars updated from user uploads."
