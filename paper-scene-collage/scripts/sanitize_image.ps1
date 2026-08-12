[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$InputPath,

    [Parameter(Position = 1)]
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$MaxInputBytes = 50MB
$MaxDecodedPixels = 50000000

try {
    Add-Type -AssemblyName System.Drawing
}
catch {
    [Console]::Error.WriteLine(('sanitize_image.ps1: {0}' -f $_.Exception.Message))
    exit 1
}

function Get-ExifOrientation {
    param([System.Drawing.Image]$Image)

    if (@($Image.PropertyIdList) -notcontains 0x0112) {
        return 1
    }

    $item = $Image.GetPropertyItem(0x0112)
    if ($null -eq $item.Value -or $item.Value.Length -lt 2) {
        throw 'The EXIF orientation property is malformed.'
    }

    $orientation = [BitConverter]::ToUInt16($item.Value, 0)
    if ($orientation -lt 1 -or $orientation -gt 8) {
        throw "Unsupported EXIF orientation value: $orientation"
    }

    return $orientation
}

function Get-RotateFlipType {
    param([int]$Orientation)

    switch ($Orientation) {
        1 { return [System.Drawing.RotateFlipType]::RotateNoneFlipNone }
        2 { return [System.Drawing.RotateFlipType]::RotateNoneFlipX }
        3 { return [System.Drawing.RotateFlipType]::Rotate180FlipNone }
        4 { return [System.Drawing.RotateFlipType]::Rotate180FlipX }
        5 { return [System.Drawing.RotateFlipType]::Rotate90FlipX }
        6 { return [System.Drawing.RotateFlipType]::Rotate90FlipNone }
        7 { return [System.Drawing.RotateFlipType]::Rotate270FlipX }
        8 { return [System.Drawing.RotateFlipType]::Rotate270FlipNone }
        default { throw "Unsupported EXIF orientation value: $Orientation" }
    }
}

function New-SensitivePropertyIdSet {
    $ids = New-Object 'System.Collections.Generic.HashSet[int]'

    foreach ($id in (0x0000..0x001F)) {
        [void]$ids.Add($id)
    }

    foreach ($id in @(
        0x010E, 0x010F, 0x0110, 0x0112, 0x011A, 0x011B, 0x0128,
        0x0131, 0x0132, 0x013B, 0x0201, 0x0202, 0x02BC, 0x8298,
        0x83BB, 0x8649, 0x8769, 0x8825, 0x9000, 0x9003, 0x9004,
        0x927C, 0x9286, 0xA005, 0xA430, 0xA431, 0xA432, 0xA433,
        0xA434, 0xA435, 0x5012, 0x5013, 0x5014, 0x5015, 0x5016,
        0x5017, 0x5018, 0x5019, 0x501B
    )) {
        [void]$ids.Add($id)
    }

    foreach ($id in (0x9101..0x9102)) { [void]$ids.Add($id) }
    foreach ($id in (0x9201..0x920A)) { [void]$ids.Add($id) }
    foreach ($id in (0x9290..0x9292)) { [void]$ids.Add($id) }
    foreach ($id in (0xA000..0xA004)) { [void]$ids.Add($id) }
    foreach ($id in (0xA20B..0xA217)) { [void]$ids.Add($id) }
    foreach ($id in (0xA300..0xA302)) { [void]$ids.Add($id) }
    foreach ($id in (0xA401..0xA420)) { [void]$ids.Add($id) }

    return ,$ids
}

$createdOutputPath = $null

try {
    $resolvedInput = Resolve-Path -LiteralPath $InputPath -ErrorAction Stop
    if ($resolvedInput.Provider.Name -ne 'FileSystem' -or -not [System.IO.File]::Exists($resolvedInput.ProviderPath)) {
        throw "Input is not a file: $InputPath"
    }
    $sourceFullPath = [System.IO.Path]::GetFullPath($resolvedInput.ProviderPath)
    $sourceLength = [System.IO.FileInfo]::new($sourceFullPath).Length
    if ($sourceLength -gt $MaxInputBytes) {
        throw "Input exceeds the 50 MiB sanitizer limit: $sourceLength bytes"
    }

    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        $outputFullPath = Join-Path ([System.IO.Path]::GetTempPath()) (
            'paper-scene-sanitized-{0}.png' -f [Guid]::NewGuid().ToString('N')
        )
    }
    else {
        $unresolvedOutput = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
        $outputFullPath = [System.IO.Path]::GetFullPath($unresolvedOutput)
    }

    if ([System.IO.Path]::GetExtension($outputFullPath) -ine '.png') {
        throw 'OutputPath must use the .png extension.'
    }
    if ([StringComparer]::OrdinalIgnoreCase.Equals($sourceFullPath, $outputFullPath)) {
        throw 'InputPath and OutputPath must be different files.'
    }
    if ([System.IO.File]::Exists($outputFullPath) -or [System.IO.Directory]::Exists($outputFullPath)) {
        throw "OutputPath already exists: $outputFullPath"
    }
    $outputDirectory = [System.IO.Path]::GetDirectoryName($outputFullPath)
    if ([string]::IsNullOrWhiteSpace($outputDirectory) -or -not [System.IO.Directory]::Exists($outputDirectory)) {
        throw "Output directory does not exist: $outputDirectory"
    }

    $source = $null
    $sanitized = $null
    $graphics = $null
    $outputStream = $null
    try {
        $source = [System.Drawing.Image]::FromFile($sourceFullPath, $true)
        $decodedWidth = $source.Width
        $decodedHeight = $source.Height
        if ($decodedWidth -le 0 -or $decodedHeight -le 0) {
            throw 'The decoded image has invalid dimensions.'
        }
        $decodedPixels = [int64]$decodedWidth * [int64]$decodedHeight
        if ($decodedPixels -gt $MaxDecodedPixels) {
            throw "Decoded image exceeds the 50 megapixel sanitizer limit: $decodedWidth x $decodedHeight"
        }

        $orientation = Get-ExifOrientation -Image $source
        $rotateFlip = Get-RotateFlipType -Orientation $orientation
        if ($rotateFlip -ne [System.Drawing.RotateFlipType]::RotateNoneFlipNone) {
            $source.RotateFlip($rotateFlip)
        }

        $expectedWidth = $source.Width
        $expectedHeight = $source.Height
        $sanitized = [System.Drawing.Bitmap]::new(
            $expectedWidth,
            $expectedHeight,
            [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
        )
        $graphics = [System.Drawing.Graphics]::FromImage($sanitized)
        $graphics.Clear([System.Drawing.Color]::White)
        $graphics.DrawImageUnscaled($source, 0, 0, $expectedWidth, $expectedHeight)
        $graphics.Dispose()
        $graphics = $null

        $outputStream = [System.IO.FileStream]::new(
            $outputFullPath,
            [System.IO.FileMode]::CreateNew,
            [System.IO.FileAccess]::Write,
            [System.IO.FileShare]::None
        )
        $createdOutputPath = $outputFullPath
        $sanitized.Save($outputStream, [System.Drawing.Imaging.ImageFormat]::Png)
        $outputStream.Flush($true)
        $outputStream.Dispose()
        $outputStream = $null
    }
    finally {
        if ($null -ne $outputStream) {
            $outputStream.Dispose()
        }
        if ($null -ne $graphics) {
            $graphics.Dispose()
        }
        if ($null -ne $sanitized) {
            $sanitized.Dispose()
        }
        if ($null -ne $source) {
            $source.Dispose()
        }
    }

    $verified = $null
    $decodeProbe = $null
    try {
        $verified = [System.Drawing.Image]::FromFile($outputFullPath, $true)
        $pngGuid = ([System.Drawing.Imaging.ImageFormat]::Png).Guid
        if ($verified.RawFormat.Guid -ne $pngGuid) {
            throw 'The sanitized output is not a decodable PNG.'
        }
        if ($verified.Width -ne $expectedWidth -or $verified.Height -ne $expectedHeight) {
            throw "Sanitized dimensions do not match the orientation-corrected image: expected ${expectedWidth}x${expectedHeight}, got $($verified.Width)x$($verified.Height)."
        }

        $decodeProbe = [System.Drawing.Bitmap]::new($verified)
        [void]$decodeProbe.GetPixel(0, 0)

        $sensitiveIds = New-SensitivePropertyIdSet
        $sensitivePropertyCount = 0
        foreach ($id in @($verified.PropertyIdList)) {
            if ($sensitiveIds.Contains([int]$id)) {
                $sensitivePropertyCount++
            }
        }
        if ($sensitivePropertyCount -ne 0) {
            throw "Sanitized output still contains $sensitivePropertyCount sensitive metadata properties."
        }
    }
    finally {
        if ($null -ne $decodeProbe) {
            $decodeProbe.Dispose()
        }
        if ($null -ne $verified) {
            $verified.Dispose()
        }
    }

    $result = [ordered]@{
        sanitized_path = $outputFullPath
        width = $expectedWidth
        height = $expectedHeight
        sensitive_property_count = $sensitivePropertyCount
    }
    [Console]::Out.WriteLine(($result | ConvertTo-Json -Compress))
}
catch {
    $message = $_.Exception.Message
    if ($null -ne $createdOutputPath -and [System.IO.File]::Exists($createdOutputPath)) {
        try {
            [System.IO.File]::Delete($createdOutputPath)
        }
        catch {
            $message = '{0} Cleanup also failed for {1}: {2}' -f $message, $createdOutputPath, $_.Exception.Message
        }
    }
    [Console]::Error.WriteLine(('sanitize_image.ps1: {0}' -f $message))
    exit 1
}
