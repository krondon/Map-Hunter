Add-Type -AssemblyName System.Drawing

function Process-And-Crop-Image {
    param(
        [string]$sourcePath,
        [string]$targetPath,
        [int]$x,
        [int]$y,
        [int]$width,
        [int]$height
    )
    
    if (!(Test-Path $sourcePath)) {
        Write-Host "Error: Source not found: $sourcePath"
        return
    }

    # Load original
    $sourceImg = [System.Drawing.Bitmap]::FromFile($sourcePath)
    
    # Auto-detect background color from top-left pixel
    $bgColor = $sourceImg.GetPixel(0, 0)
    
    # Create target with transparency
    $targetImg = New-Object System.Drawing.Bitmap($width, $height)
    $graphics = [System.Drawing.Graphics]::FromImage($targetImg)
    
    # Manual pixel copy loop to apply Tolerance
    # This is slower but much better for removing "almost blue" pixels
    $tolerance = 100 # Adjust tolerance (0-255)
    
    for ($py = 0; $py -lt $height; $py++) {
        for ($px = 0; $px -lt $width; $px++) {
             $srcX = $x + $px
             $srcY = $y + $py
             
             if ($srcX -lt $sourceImg.Width -and $srcY -lt $sourceImg.Height) {
                $pixel = $sourceImg.GetPixel($srcX, $srcY)
                
                # Calculate distance
                $diffR = [Math]::Abs($pixel.R - $bgColor.R)
                $diffG = [Math]::Abs($pixel.G - $bgColor.G)
                $diffB = [Math]::Abs($pixel.B - $bgColor.B)
                
                if (($diffR + $diffG + $diffB) -lt $tolerance) {
                    # Transparent
                } else {
                    $targetImg.SetPixel($px, $py, $pixel)
                }
             }
        }
    }
    
    # Save
    $targetImg.Save($targetPath, [System.Drawing.Imaging.ImageFormat]::Png)
    
    # Cleanup
    $graphics.Dispose()
    $targetImg.Dispose()
    $sourceImg.Dispose()
    
    Write-Host "Saved transparent avatar: $targetPath"
}

$avatarDir = "c:\Users\natac\Desktop\Busqueda_del_tesoro\Juego_QR\assets\images\avatars"
if (!(Test-Path $avatarDir)) { New-Item -ItemType Directory -Path $avatarDir }

# Rutas originales de las imagenes generadas
$maleSource = "C:\Users\natac\.gemini\antigravity\brain\2172836a-2969-42d0-9ccc-76316eed3889\maphunter_avatars_v1_1769362900028.png"
$femaleSource = "C:\Users\natac\.gemini\antigravity\brain\2172836a-2969-42d0-9ccc-76316eed3889\maphunter_avatars_women_v2_consistent_1769363015289.png"

# --- Hombres ---
# 0,0 is Top-Left
Process-And-Crop-Image $maleSource "$avatarDir\explorer_m.png" 0 0 512 512
Process-And-Crop-Image $maleSource "$avatarDir\hacker_m.png" 512 0 512 512
Process-And-Crop-Image $maleSource "$avatarDir\warrior_m.png" 0 512 512 400
Process-And-Crop-Image $maleSource "$avatarDir\spec_m.png" 512 512 512 400

# --- Mujeres ---
Process-And-Crop-Image $femaleSource "$avatarDir\explorer_f.png" 0 0 512 512
Process-And-Crop-Image $femaleSource "$avatarDir\hacker_f.png" 512 0 512 512
Process-And-Crop-Image $femaleSource "$avatarDir\warrior_f.png" 0 512 512 400
Process-And-Crop-Image $femaleSource "$avatarDir\spec_f.png" 512 512 512 400

Write-Host "All avatars processed with transparency!"
