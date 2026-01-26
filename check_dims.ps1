Add-Type -AssemblyName System.Drawing

function Get-ImageDimensions {
    param([string]$path)
    if (Test-Path $path) {
        $img = [System.Drawing.Image]::FromFile($path)
        Write-Host "Image: $(Split-Path $path -Leaf) | Width: $($img.Width) | Height: $($img.Height)"
        $img.Dispose()
    } else {
        Write-Host "File not found: $path"
    }
}

$maleSource = "C:\Users\natac\.gemini\antigravity\brain\2172836a-2969-42d0-9ccc-76316eed3889\uploaded_media_1_1769366798667.png"
$femaleSource = "C:\Users\natac\.gemini\antigravity\brain\2172836a-2969-42d0-9ccc-76316eed3889\uploaded_media_0_1769366798667.png"

Get-ImageDimensions $maleSource
Get-ImageDimensions $femaleSource
