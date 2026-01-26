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
    
    $graphics.Clear([System.Drawing.Color]::Transparent)
    
    $destRect = New-Object System.Drawing.Rectangle(0, 0, $width, $height)
    $srcRect = New-Object System.Drawing.Rectangle($x, $y, $width, $height)
    
    $graphics.DrawImage($sourceImg, $destRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
    
    $targetImg.Save($targetPath, [System.Drawing.Imaging.ImageFormat]::Png)
    
    $graphics.Dispose()
    $targetImg.Dispose()
    $sourceImg.Dispose()
    
    Write-Host "Saved: $targetPath"
}

$avatarDir = "c:\Users\natac\Desktop\Busqueda_del_tesoro\Juego_QR\assets\images\avatars"
if (!(Test-Path $avatarDir)) { New-Item -ItemType Directory -Path $avatarDir }

$source = "C:\Users\natac\.gemini\antigravity\brain\2172836a-2969-42d0-9ccc-76316eed3889\uploaded_media_1769368560869.png"

$w = 144
$h = 216
$row2_y = 216

# Row 1: Females
Crop-Image $source "$avatarDir\explorer_f.png" (0*$w) 0 $w $h
Crop-Image $source "$avatarDir\hacker_f.png"   (1*$w) 0 $w $h
Crop-Image $source "$avatarDir\warrior_f.png"  (2*$w) 0 $w $h
Crop-Image $source "$avatarDir\spec_f.png"     (3*$w) 0 $w $h

# Row 2: Males
Crop-Image $source "$avatarDir\explorer_m.png" (0*$w) $row2_y $w $h
Crop-Image $source "$avatarDir\hacker_m.png"   (1*$w) $row2_y $w $h
Crop-Image $source "$avatarDir\warrior_m.png"  (2*$w) $row2_y $w $h
Crop-Image $source "$avatarDir\spec_m.png"     (3*$w) $row2_y $w $h

Write-Host "All 8 avatars cropped from single sheet."
