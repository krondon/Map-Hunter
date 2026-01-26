Add-Type -AssemblyName System.Drawing

$path = "C:\Users\natac\.gemini\antigravity\brain\2172836a-2969-42d0-9ccc-76316eed3889\uploaded_media_1769368560869.png"
if (Test-Path $path) {
    $img = [System.Drawing.Image]::FromFile($path)
    Write-Host "Width: $($img.Width) | Height: $($img.Height)"
    $img.Dispose()
} else {
    Write-Host "File not found"
}
