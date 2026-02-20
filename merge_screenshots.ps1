$ErrorActionPreference = "Stop"

$baseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$mergeDir = Join-Path $baseDir "merge"
$archiveDir = Join-Path $baseDir "archive"

$null = New-Item -ItemType Directory -Force -Path $mergeDir
$null = New-Item -ItemType Directory -Force -Path $archiveDir

$validExt = @('.png', '.jpg', '.jpeg', '.bmp')
$shots = Get-ChildItem -LiteralPath $baseDir -File |
    Where-Object { $validExt -contains $_.Extension.ToLowerInvariant() } |
    Sort-Object LastWriteTime, Name

if (-not $shots -or $shots.Count -eq 0) {
    Write-Output "No screenshots found in current folder."
    exit 0
}

function Select-ForMerge {
    param([System.IO.FileInfo[]]$files)

    $arr = @($files)
    $n = [int]$arr.Length

    if ($n -le 4) {
        return $arr
    }

    $idx = @(
        0,
        [int][Math]::Floor(($n - 1) / 3),
        [int][Math]::Floor((($n - 1) * 2) / 3),
        $n - 1
    )

    $seen = @{}
    $selected = New-Object System.Collections.Generic.List[System.IO.FileInfo]
    foreach ($i in $idx) {
        if (-not $seen.ContainsKey($i)) {
            $seen[$i] = $true
            $selected.Add($arr[$i])
        }
    }

    return $selected.ToArray()
}

function Move-WithUniqueName {
    param(
        [Parameter(Mandatory = $true)][System.IO.FileInfo]$file,
        [Parameter(Mandatory = $true)][string]$destDir
    )

    $name = $file.Name
    $target = Join-Path $destDir $name
    if (-not (Test-Path -LiteralPath $target)) {
        Move-Item -LiteralPath $file.FullName -Destination $target -Force
        return
    }

    $stem = [System.IO.Path]::GetFileNameWithoutExtension($name)
    $ext = [System.IO.Path]::GetExtension($name)
    $i = 1
    while ($true) {
        $candidate = Join-Path $destDir ("{0}_{1}{2}" -f $stem, $i, $ext)
        if (-not (Test-Path -LiteralPath $candidate)) {
            Move-Item -LiteralPath $file.FullName -Destination $candidate -Force
            return
        }
        $i++
    }
}

$selected = Select-ForMerge -files $shots

Add-Type -AssemblyName System.Drawing

$images = New-Object System.Collections.Generic.List[System.Drawing.Image]
try {
    foreach ($f in $selected) {
        $img = [System.Drawing.Image]::FromFile($f.FullName)
        $images.Add($img)
    }

    if ($images.Count -eq 0) {
        Write-Output "No readable images."
        exit 2
    }

    $margin = 0
    $maxWidth = 0
    $totalHeight = 0
    foreach ($img in $images) {
        if ($img.Width -gt $maxWidth) {
            $maxWidth = $img.Width
        }
        $totalHeight += $img.Height
    }

    if ($maxWidth -le 0 -or $totalHeight -le 0) {
        Write-Output "Invalid image dimensions."
        exit 3
    }

    $canvas = New-Object System.Drawing.Bitmap($maxWidth, $totalHeight)
    $g = [System.Drawing.Graphics]::FromImage($canvas)
    try {
        $y = 0
        foreach ($img in $images) {
            $x = [int](($maxWidth - $img.Width) / 2)
            $g.DrawImage($img, $x, $y, $img.Width, $img.Height)
            $y += $img.Height
        }

        $outName = "merged_{0}.jpg" -f (Get-Date -Format "yyyyMMdd_HHmmss")
        $outPath = Join-Path $mergeDir $outName
        $jpgCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
            Where-Object { $_.MimeType -eq "image/jpeg" } |
            Select-Object -First 1
        if ($null -ne $jpgCodec) {
            $encParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
            $quality = New-Object System.Drawing.Imaging.EncoderParameter(
                [System.Drawing.Imaging.Encoder]::Quality, [long]80
            )
            $encParams.Param[0] = $quality
            $canvas.Save($outPath, $jpgCodec, $encParams)
            $quality.Dispose()
            $encParams.Dispose()
        }
        else {
            $canvas.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Jpeg)
        }
        Write-Output ("Merged: {0}" -f $outPath)
    }
    finally {
        $g.Dispose()
        $canvas.Dispose()
    }
}
finally {
    foreach ($img in $images) {
        $img.Dispose()
    }
}

foreach ($shot in $shots) {
    Move-WithUniqueName -file $shot -destDir $archiveDir
}

Write-Output ("Archive moved: {0} files -> {1}" -f $shots.Count, $archiveDir)
exit 0
