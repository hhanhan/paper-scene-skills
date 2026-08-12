[CmdletBinding()]
param(
    [string]$SanitizerPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# This test intentionally creates all image fixtures at runtime.  A portable,
# deterministic way to fail after FileMode.CreateNew is not available across
# Windows runners, so the negative cases below focus on the sanitizer's
# preflight rejection paths and assert that they never create an output.

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Get-FullPath {
    param([string]$Path)

    return [System.IO.Path]::GetFullPath(
        $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    )
}

function Assert-SafeTestDirectory {
    param(
        [string]$Path,
        [bool]$MustExist = $true
    )

    $tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    $tempRoot = $tempRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    $resolved = [System.IO.Path]::GetFullPath($Path)
    $leaf = [System.IO.Path]::GetFileName($resolved.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar))
    $underTemp = $resolved.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase)
    $validName = $leaf -match '^paper-scene-sanitize-test-[0-9a-f]{32}$'

    Assert-True $underTemp "Refusing to use a test directory outside the system temp root: $resolved"
    Assert-True $validName "Refusing to use a test directory with an unexpected name: $resolved"
    if ($MustExist) {
        Assert-True ([System.IO.Directory]::Exists($resolved)) "Test directory does not exist: $resolved"
    }

    return $resolved
}

function Remove-SafeTestDirectory {
    param([string]$Path)

    $resolved = Assert-SafeTestDirectory -Path $Path -MustExist:$false
    if ([System.IO.Directory]::Exists($resolved)) {
        Remove-Item -LiteralPath $resolved -Recurse -Force
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

function Get-SensitivePropertyCount {
    param([System.Drawing.Image]$Image)

    $ids = New-SensitivePropertyIdSet
    $count = 0
    foreach ($id in @($Image.PropertyIdList)) {
        if ($ids.Contains([int]$id)) {
            $count++
        }
    }
    return $count
}

function New-OrientationPropertyItem {
    param([int]$Orientation)

    $item = [System.Runtime.Serialization.FormatterServices]::GetUninitializedObject(
        [System.Drawing.Imaging.PropertyItem]
    )
    $item.Id = 0x0112
    $item.Type = 3
    $item.Len = 2
    $item.Value = [BitConverter]::GetBytes([UInt16]$Orientation)
    return $item
}

function New-MetadataPropertyItem {
    param(
        [int]$Id,
        [Int16]$Type,
        [byte[]]$Bytes
    )

    $item = [System.Runtime.Serialization.FormatterServices]::GetUninitializedObject(
        [System.Drawing.Imaging.PropertyItem]
    )
    $item.Id = $Id
    $item.Type = $Type
    $item.Len = $Bytes.Length
    $item.Value = $Bytes
    return $item
}

function Test-ByteSequence {
    param(
        [byte[]]$Bytes,
        [byte[]]$Needle
    )

    if ($null -eq $Bytes -or $null -eq $Needle -or $Needle.Length -eq 0 -or $Bytes.Length -lt $Needle.Length) {
        return $false
    }
    for ($i = 0; $i -le $Bytes.Length - $Needle.Length; $i++) {
        $match = $true
        for ($j = 0; $j -lt $Needle.Length; $j++) {
            if ($Bytes[$i + $j] -ne $Needle[$j]) {
                $match = $false
                break
            }
        }
        if ($match) {
            return $true
        }
    }
    return $false
}

function Get-MetadataSentinelBytes {
    return [System.Text.Encoding]::ASCII.GetBytes('PAPER_SCENE_PRIVATE_SENTINEL_8F4D2E7A')
}

function Assert-SourceMetadataFixture {
    param([System.Drawing.Image]$Image)

    $sentinel = Get-MetadataSentinelBytes
    foreach ($id in @(0x010E, 0x013B)) {
        Assert-True (@($Image.PropertyIdList) -contains $id) "System.Drawing did not persist required metadata property 0x$('{0:X4}' -f $id)."
        $property = $Image.GetPropertyItem($id)
        Assert-True (Test-ByteSequence -Bytes $property.Value -Needle $sentinel) "Source metadata property 0x$('{0:X4}' -f $id) did not retain the sentinel."
    }
    # System.Drawing rewrites UserComment payloads while saving JPEGs on some
    # Windows builds.  Require the sensitive tag and non-empty bytes, while
    # using the stable ImageDescription/Artist tags for sentinel propagation.
    Assert-True (@($Image.PropertyIdList) -contains 0x9286) 'System.Drawing did not persist the UserComment metadata tag.'
    $comment = $Image.GetPropertyItem(0x9286)
    Assert-True ($comment.Len -gt 0 -and $comment.Value.Length -gt 0) 'Persisted UserComment metadata is empty.'
}

function Assert-NoMetadataSentinel {
    param([System.Drawing.Image]$Image)

    $sentinel = Get-MetadataSentinelBytes
    foreach ($id in @($Image.PropertyIdList)) {
        $property = $Image.GetPropertyItem($id)
        Assert-True (-not (Test-ByteSequence -Bytes $property.Value -Needle $sentinel)) "Sanitized output retained the metadata sentinel in property 0x$('{0:X4}' -f $id)."
    }
}

function New-JpegCodecParameters {
    $codec = $null
    foreach ($candidate in [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders()) {
        if ($candidate.MimeType -eq 'image/jpeg') {
            $codec = $candidate
            break
        }
    }
    Assert-True ($null -ne $codec) 'System.Drawing did not expose a JPEG encoder.'

    $parameters = [System.Drawing.Imaging.EncoderParameters]::new(1)
    $parameters.Param[0] = [System.Drawing.Imaging.EncoderParameter]::new(
        [System.Drawing.Imaging.Encoder]::Quality,
        [Int64]100
    )
    return @($codec, $parameters)
}

function New-OrientationFixture {
    param(
        [string]$Path,
        [int]$Orientation,
        [int]$Width = 80,
        [int]$Height = 60
    )

    $bitmap = $null
    $graphics = $null
    $codec = $null
    $parameters = $null
    try {
        $bitmap = [System.Drawing.Bitmap]::new(
            $Width,
            $Height,
            [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
        )
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.Clear([System.Drawing.Color]::FromArgb(224, 224, 224))

        $blockWidth = [int]($Width / 3)
        $blockHeight = [int]($Height / 3)
        $graphics.FillRectangle([System.Drawing.Brushes]::Red, 0, 0, $blockWidth, $blockHeight)
        $graphics.FillRectangle([System.Drawing.Brushes]::LimeGreen, $Width - $blockWidth, 0, $blockWidth, $blockHeight)
        $graphics.FillRectangle([System.Drawing.Brushes]::RoyalBlue, $Width - $blockWidth, $Height - $blockHeight, $blockWidth, $blockHeight)
        $graphics.FillRectangle([System.Drawing.Brushes]::Gold, 0, $Height - $blockHeight, $blockWidth, $blockHeight)
        $graphics.FillRectangle([System.Drawing.Brushes]::Black, [int]($Width / 2) - 2, [int]($Height / 2) - 2, 5, 5)
        $graphics.Dispose()
        $graphics = $null

        $bitmap.SetPropertyItem((New-OrientationPropertyItem -Orientation $Orientation))
        $sentinel = Get-MetadataSentinelBytes
        $descriptionBytes = [System.Text.Encoding]::ASCII.GetBytes(
            ('PaperSceneDescription|{0}|0' -f [System.Text.Encoding]::ASCII.GetString($sentinel))
        )
        $artistBytes = [System.Text.Encoding]::ASCII.GetBytes(
            ('PaperSceneArtist|{0}|0' -f [System.Text.Encoding]::ASCII.GetString($sentinel))
        )
        $commentBytes = [System.Text.Encoding]::ASCII.GetBytes(
            ('PaperSceneUserComment|{0}' -f [System.Text.Encoding]::ASCII.GetString($sentinel))
        )
        $bitmap.SetPropertyItem((New-MetadataPropertyItem -Id 0x010E -Type 2 -Bytes $descriptionBytes))
        $bitmap.SetPropertyItem((New-MetadataPropertyItem -Id 0x013B -Type 2 -Bytes $artistBytes))
        # Type 2 keeps malformed EXIF UserComment payloads from crashing
        # System.Drawing while still exercising removal of the sensitive tag.
        $bitmap.SetPropertyItem((New-MetadataPropertyItem -Id 0x9286 -Type 2 -Bytes $commentBytes))
        $codecAndParameters = New-JpegCodecParameters
        $codec = $codecAndParameters[0]
        $parameters = $codecAndParameters[1]
        $bitmap.Save($Path, $codec, $parameters)
    }
    finally {
        if ($null -ne $parameters) {
            if ($null -ne $parameters.Param[0]) {
                $parameters.Param[0].Dispose()
            }
            $parameters.Dispose()
        }
        if ($null -ne $codec) {
            $codec = $null
        }
        if ($null -ne $graphics) {
            $graphics.Dispose()
        }
        if ($null -ne $bitmap) {
            $bitmap.Dispose()
        }
    }

    $probe = $null
    try {
        $probe = [System.Drawing.Image]::FromFile($Path, $true)
        Assert-True (@($probe.PropertyIdList) -contains 0x0112) "System.Drawing did not persist EXIF orientation metadata for value $Orientation."
        $item = $probe.GetPropertyItem(0x0112)
        Assert-True ($item.Type -eq 3 -and $item.Len -ge 2) "System.Drawing wrote malformed EXIF orientation metadata for value $Orientation."
        $persisted = [BitConverter]::ToUInt16($item.Value, 0)
        Assert-True ($persisted -eq $Orientation) "System.Drawing persisted EXIF orientation $persisted instead of $Orientation."
        Assert-SourceMetadataFixture -Image $probe
    }
    finally {
        if ($null -ne $probe) {
            $probe.Dispose()
        }
    }
}

function Get-CornerColors {
    param([System.Drawing.Image]$Image)

    $margin = [Math]::Max(8, [Math]::Min([int]($Image.Width / 8), [int]($Image.Height / 8)))
    return [ordered]@{
        TL = $Image.GetPixel($margin, $margin)
        TR = $Image.GetPixel($Image.Width - 1 - $margin, $margin)
        BR = $Image.GetPixel($Image.Width - 1 - $margin, $Image.Height - 1 - $margin)
        BL = $Image.GetPixel($margin, $Image.Height - 1 - $margin)
    }
}

function Get-CornerPoint {
    param(
        [System.Drawing.Image]$Image,
        [string]$Name
    )

    $margin = [Math]::Max(8, [Math]::Min([int]($Image.Width / 8), [int]($Image.Height / 8)))
    switch ($Name) {
        TL { return [System.Drawing.Point]::new($margin, $margin) }
        TR { return [System.Drawing.Point]::new($Image.Width - 1 - $margin, $margin) }
        BR { return [System.Drawing.Point]::new($Image.Width - 1 - $margin, $Image.Height - 1 - $margin) }
        BL { return [System.Drawing.Point]::new($margin, $Image.Height - 1 - $margin) }
        default { throw "Unknown corner: $Name" }
    }
}

function Assert-ColorClose {
    param(
        [System.Drawing.Color]$Actual,
        [System.Drawing.Color]$Expected,
        [string]$Message
    )

    $dr = [int]$Actual.R - [int]$Expected.R
    $dg = [int]$Actual.G - [int]$Expected.G
    $db = [int]$Actual.B - [int]$Expected.B
    $distance = [Math]::Sqrt(($dr * $dr) + ($dg * $dg) + ($db * $db))
    Assert-True ($distance -le 75) ("{0} (distance {1:N1})" -f $Message, $distance)
}

function Invoke-Sanitizer {
    param(
        [string]$InputPath,
        [string]$OutputPath,
        [string]$ErrorPath
    )

    $previousErrorActionPreference = $ErrorActionPreference
    try {
        # The child intentionally writes diagnostics to stderr for negative
        # cases.  Keep those diagnostics non-terminating while retaining the
        # real exit code and checking the captured text below.
        $ErrorActionPreference = 'Continue'
        $stdoutLines = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $SanitizerPath -InputPath $InputPath -OutputPath $OutputPath 2> $ErrorPath)
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    $stdout = ($stdoutLines -join [Environment]::NewLine).Trim()
    $stderr = ''
    if ([System.IO.File]::Exists($ErrorPath)) {
        $stderrContent = Get-Content -LiteralPath $ErrorPath -Raw
        if ($null -ne $stderrContent) {
            $stderr = $stderrContent.Trim()
        }
    }
    return [ordered]@{
        ExitCode = $exitCode
        Stdout = $stdout
        Stderr = $stderr
    }
}

function Assert-SanitizerOutput {
    param(
        [string]$InputPath,
        [string]$OutputPath,
        [string]$ErrorPath,
        [int]$ExpectedWidth,
        [int]$ExpectedHeight,
        [hashtable]$ExpectedSourceCornerForOutput,
        [hashtable]$SourceCorners,
        [string]$SourceHashBefore
    )

    $invocation = Invoke-Sanitizer -InputPath $InputPath -OutputPath $OutputPath -ErrorPath $ErrorPath
    Assert-True ($invocation.ExitCode -eq 0) ("Sanitizer failed: $($invocation.Stderr)")
    Assert-True (-not [string]::IsNullOrWhiteSpace($invocation.Stdout)) 'Sanitizer did not emit JSON.'

    try {
        $payload = $invocation.Stdout | ConvertFrom-Json
    }
    catch {
        throw "Sanitizer output was not valid JSON: $($invocation.Stdout)"
    }

    $keys = @($payload.PSObject.Properties.Name | Sort-Object)
    $expectedKeys = @('height', 'sanitized_path', 'sensitive_property_count', 'width')
    Assert-True (($keys -join '|') -eq ($expectedKeys -join '|')) ("Unexpected sanitizer JSON keys: $($keys -join ', ')")

    Assert-True ([int]$payload.width -eq $ExpectedWidth) "JSON width is not $ExpectedWidth."
    Assert-True ([int]$payload.height -eq $ExpectedHeight) "JSON height is not $ExpectedHeight."
    Assert-True ([int]$payload.sensitive_property_count -eq 0) 'JSON reported sensitive metadata.'

    $returnedPath = Get-FullPath -Path ([string]$payload.sanitized_path)
    $requestedPath = Get-FullPath -Path $OutputPath
    Assert-True ([StringComparer]::OrdinalIgnoreCase.Equals($returnedPath, $requestedPath)) 'Sanitizer returned a different output path.'
    Assert-True (-not [StringComparer]::OrdinalIgnoreCase.Equals((Get-FullPath -Path $InputPath), $returnedPath)) 'Sanitizer output path is not distinct from the input path.'
    Assert-True ([System.IO.Path]::GetExtension($returnedPath) -ieq '.png') 'Sanitizer output path is not a PNG.'
    Assert-True ([System.IO.File]::Exists($returnedPath)) 'Sanitizer output file does not exist.'

    $output = $null
    $probe = $null
    try {
        $output = [System.Drawing.Image]::FromFile($returnedPath, $true)
        $pngGuid = ([System.Drawing.Imaging.ImageFormat]::Png).Guid
        Assert-True ($output.RawFormat.Guid -eq $pngGuid) 'Independent System.Drawing decode did not identify a PNG.'
        Assert-True ($output.Width -eq $ExpectedWidth -and $output.Height -eq $ExpectedHeight) 'Independent decode dimensions differ from JSON.'
        Assert-True ($output.Width -gt 0 -and $output.Height -gt 0) 'Sanitized output dimensions are not positive.'
        Assert-True ((Get-SensitivePropertyCount -Image $output) -eq 0) 'Independent metadata scan found sensitive properties.'
        Assert-NoMetadataSentinel -Image $output

        foreach ($corner in @('TL', 'TR', 'BR', 'BL')) {
            $point = Get-CornerPoint -Image $output -Name $corner
            $actual = $output.GetPixel($point.X, $point.Y)
            $sourceCorner = $ExpectedSourceCornerForOutput[$corner]
            Assert-ColorClose -Actual $actual -Expected $SourceCorners[$sourceCorner] -Message "Orientation corner $corner did not map from source $sourceCorner."
        }
    }
    finally {
        if ($null -ne $probe) {
            $probe.Dispose()
        }
        if ($null -ne $output) {
            $output.Dispose()
        }
    }

    $sourceHashAfter = (Get-FileHash -LiteralPath $InputPath -Algorithm SHA256).Hash
    Assert-True ($sourceHashAfter -eq $SourceHashBefore) 'Sanitizer changed the source image.'
}

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Runtime.Serialization

$script:SanitizerPath = if ([string]::IsNullOrWhiteSpace($SanitizerPath)) {
    Join-Path $PSScriptRoot '..\paper-scene-collage\scripts\sanitize_image.ps1'
}
else {
    $SanitizerPath
}

$sanitizerFullPath = Get-FullPath -Path $SanitizerPath
Assert-True ([System.IO.File]::Exists($sanitizerFullPath)) "Sanitizer script does not exist: $sanitizerFullPath"

$testDirectory = Join-Path ([System.IO.Path]::GetTempPath()) (
    'paper-scene-sanitize-test-{0}' -f [Guid]::NewGuid().ToString('N')
)
$testDirectory = Assert-SafeTestDirectory -Path $testDirectory -MustExist:$false

try {
    [System.IO.Directory]::CreateDirectory($testDirectory) | Out-Null
    Assert-SafeTestDirectory -Path $testDirectory | Out-Null

    $cornerMaps = @{
        1 = @{ TL = 'TL'; TR = 'TR'; BR = 'BR'; BL = 'BL' }
        2 = @{ TL = 'TR'; TR = 'TL'; BR = 'BL'; BL = 'BR' }
        3 = @{ TL = 'BR'; TR = 'BL'; BR = 'TL'; BL = 'TR' }
        4 = @{ TL = 'BL'; TR = 'BR'; BR = 'TR'; BL = 'TL' }
        5 = @{ TL = 'TL'; TR = 'BL'; BR = 'BR'; BL = 'TR' }
        6 = @{ TL = 'BL'; TR = 'TL'; BR = 'TR'; BL = 'BR' }
        7 = @{ TL = 'BR'; TR = 'TR'; BR = 'TL'; BL = 'BL' }
        8 = @{ TL = 'TR'; TR = 'BR'; BR = 'BL'; BL = 'TL' }
    }

    foreach ($orientation in 1..8) {
        $inputPath = Join-Path $testDirectory ("orientation-{0}.jpg" -f $orientation)
        $outputPath = Join-Path $testDirectory ("orientation-{0}.png" -f $orientation)
        $errorPath = Join-Path $testDirectory ("orientation-{0}.stderr.txt" -f $orientation)
        New-OrientationFixture -Path $inputPath -Orientation $orientation

        $source = $null
        try {
            $source = [System.Drawing.Image]::FromFile($inputPath, $true)
            $sourceCorners = Get-CornerColors -Image $source
            $sourceHashBefore = (Get-FileHash -LiteralPath $inputPath -Algorithm SHA256).Hash
            $expectedWidth = if ($orientation -ge 5) { $source.Height } else { $source.Width }
            $expectedHeight = if ($orientation -ge 5) { $source.Width } else { $source.Height }
            Assert-SanitizerOutput -InputPath $inputPath -OutputPath $outputPath -ErrorPath $errorPath -ExpectedWidth $expectedWidth -ExpectedHeight $expectedHeight -ExpectedSourceCornerForOutput $cornerMaps[$orientation] -SourceCorners $sourceCorners -SourceHashBefore $sourceHashBefore
        }
        finally {
            if ($null -ne $source) {
                $source.Dispose()
            }
        }
    }

    $negativeInput = Join-Path $testDirectory 'negative-input.jpg'
    New-OrientationFixture -Path $negativeInput -Orientation 1
    $negativePng = Join-Path $testDirectory 'negative-input.png'
    $negativeSourceImage = $null
    try {
        $negativeSourceImage = [System.Drawing.Image]::FromFile($negativeInput, $true)
        $negativeSourceImage.Save($negativePng, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        if ($null -ne $negativeSourceImage) {
            $negativeSourceImage.Dispose()
        }
    }
    $negativeHash = (Get-FileHash -LiteralPath $negativePng -Algorithm SHA256).Hash

    $samePathError = Join-Path $testDirectory 'negative-same.stderr.txt'
    $sameInvocation = Invoke-Sanitizer -InputPath $negativePng -OutputPath $negativePng -ErrorPath $samePathError
    Assert-True ($sameInvocation.ExitCode -ne 0) 'Sanitizer unexpectedly accepted identical input/output paths.'
    Assert-True ($sameInvocation.Stderr -match 'InputPath and OutputPath must be different files') 'Same-path rejection returned an unexpected error.'
    Assert-True ((Get-FileHash -LiteralPath $negativePng -Algorithm SHA256).Hash -eq $negativeHash) 'Same-path rejection changed the source.'

    $existingOutput = Join-Path $testDirectory 'negative-existing.png'
    [System.IO.File]::WriteAllText($existingOutput, 'pre-existing output')
    $existingHash = (Get-FileHash -LiteralPath $existingOutput -Algorithm SHA256).Hash
    $existingError = Join-Path $testDirectory 'negative-existing.stderr.txt'
    $existingInvocation = Invoke-Sanitizer -InputPath $negativeInput -OutputPath $existingOutput -ErrorPath $existingError
    Assert-True ($existingInvocation.ExitCode -ne 0) 'Sanitizer unexpectedly overwrote an existing output.'
    Assert-True ($existingInvocation.Stderr -match 'OutputPath already exists') 'Existing-output rejection returned an unexpected error.'
    Assert-True ((Get-FileHash -LiteralPath $existingOutput -Algorithm SHA256).Hash -eq $existingHash) 'Existing output changed after rejection.'

    Write-Output 'sanitize_image.ps1 regression tests passed (orientations 1-8, metadata, source immutability, and negative paths).'
}
finally {
    Remove-SafeTestDirectory -Path $testDirectory
}
