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
    
    # Create target with specific dimensions
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

$maleSource = "C:\Users\natac\.gemini\antigravity\brain\2172836a-2969-42d0-9ccc-76316eed3889\uploaded_media_1_1769366798667.png"
$femaleSource = "C:\Users\natac\.gemini\antigravity\brain\2172836a-2969-42d0-9ccc-76316eed3889\uploaded_media_0_1769366798667.png"

# Adjusted dimensions for 552x592 source images
# Half Width: 276
# Half Height: 296

$w = 276
$h = 296

# --- MALES ---
Crop-Image $maleSource "$avatarDir\explorer_m.png" 0   0   $w $h
Crop-Image $maleSource "$avatarDir\hacker_m.png"   $w  0   $w $h
Crop-Image $maleSource "$avatarDir\warrior_m.png"  0   $h  $w $h
Crop-Image $maleSource "$avatarDir\spec_m.png"     $w  $h  $w $h

# --- FEMALES ---
Crop-Image $femaleSource "$avatarDir\explorer_f.png" 0   0   $w $h
Crop-Image $femaleSource "$avatarDir\hacker_f.png"   $w  0   $w $h
Crop-Image $femaleSource "$avatarDir\warrior_f.png"  0   $h  $w $h
Crop-Image $femaleSource "$avatarDir\spec_f.png"     $w  $h  $w $h

Write-Host "Avatars re-cropped with corrected dimensions."
