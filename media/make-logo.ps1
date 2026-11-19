# Draws the Junk Drop logo: a keycap with a trash can on it (one key press, junk
# gone), on a dusk gradient (Daylight UI's plum into the plugin's amber). Writes logo-1024.png and logo-400.png here.
Add-Type -AssemblyName System.Drawing
$out = $PSScriptRoot

function RoundRect([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $p.AddArc($x, $y, $d, $d, 180, 90)
    $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $p.CloseFigure()
    return $p
}
function C([string]$hex, [int]$a = 255) {
    return [System.Drawing.Color]::FromArgb($a, [Convert]::ToInt32($hex.Substring(0,2),16),
        [Convert]::ToInt32($hex.Substring(2,2),16), [Convert]::ToInt32($hex.Substring(4,2),16))
}

$S = 1024
$bmp = New-Object System.Drawing.Bitmap $S, $S, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBicubic'; $g.PixelOffsetMode = 'HighQuality'
$g.Clear([System.Drawing.Color]::Transparent)

# Background tile: dusk gradient, plum to amber.
$bg = RoundRect 0 0 $S $S 200
$grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Point 0,0), (New-Object System.Drawing.Point $S,$S), (C "4b2a7a"), (C "e0a458")
$blend = New-Object System.Drawing.Drawing2D.ColorBlend 3
$blend.Colors = @((C "3a2266"), (C "8a4a8c"), (C "e8a85a")); $blend.Positions = @(0.0, 0.5, 1.0)
$grad.InterpolationColors = $blend
$g.FillPath($grad, $bg)

# Soft sun glow, top right.
$glow = New-Object System.Drawing.Drawing2D.GraphicsPath
$glow.AddEllipse(560, -120, 600, 600)
$pg = New-Object System.Drawing.Drawing2D.PathGradientBrush $glow
$pg.CenterColor = (C "ffd89a" 120); $pg.SurroundColors = @((C "ffd89a" 0))
$g.SetClip($bg); $g.FillPath($pg, $glow); $g.ResetClip()

# Keycap: shadow, side (darker), top face.
$kx = 232; $ky = 214; $kw = 560; $kh = 560
$shadow = RoundRect ($kx + 10) ($ky + 70) $kw $kh 110
$g.FillPath((New-Object System.Drawing.SolidBrush (C "1a0f2e" 90)), $shadow)
$side = RoundRect $kx ($ky + 40) $kw $kh 110
$g.FillPath((New-Object System.Drawing.SolidBrush (C "cdbfd6")), $side)
$top = RoundRect $kx $ky $kw $kh 110
$tg = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Point 0,$ky), (New-Object System.Drawing.Point 0,($ky + $kh)), (C "ffffff"), (C "efe6f2")
$g.FillPath($tg, $top)
# Dished inner face.
$face = RoundRect ($kx + 46) ($ky + 40) ($kw - 92) ($kh - 110) 80
$fg = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Point 0,($ky + 40)), (New-Object System.Drawing.Point 0,($ky + $kh - 70)), (C "f3ecf6"), (C "ffffff")
$g.FillPath($fg, $face)

# Trash can glyph on the key, in deep plum.
$ink = New-Object System.Drawing.SolidBrush (C "3f2563")
$cx = $kx + $kw / 2; $gy = $ky + 105
# lid and handle
$g.FillPath($ink, (RoundRect ($cx - 140) ($gy + 40) 280 34 14))
$hp = New-Object System.Drawing.Pen (C "3f2563"), 26
$hp.LineJoin = 'Round'
$g.DrawPath($hp, (RoundRect ($cx - 44) ($gy) 88 46 12))
# body, tapered, with rounded bottom
$body = New-Object System.Drawing.Drawing2D.GraphicsPath
$body.AddLines([System.Drawing.PointF[]]@(
    (New-Object System.Drawing.PointF ($cx - 118), ($gy + 92)),
    (New-Object System.Drawing.PointF ($cx + 118), ($gy + 92)),
    (New-Object System.Drawing.PointF ($cx + 96), ($gy + 300)),
    (New-Object System.Drawing.PointF ($cx - 96), ($gy + 300))))
$body.CloseFigure()
$g.FillPath($ink, $body)
$g.FillPath($ink, (RoundRect ($cx - 96) ($gy + 270) 192 50 24))
# ribs
$rib = New-Object System.Drawing.SolidBrush (C "f6f0f8")
foreach ($dx in -56, 0, 56) { $g.FillPath($rib, (RoundRect ($cx + $dx - 11) ($gy + 124) 22 160 11)) }

$g.Dispose()
$bmp.Save((Join-Path $out "logo-1024.png"), [System.Drawing.Imaging.ImageFormat]::Png)

$small = New-Object System.Drawing.Bitmap 400, 400
$sg = [System.Drawing.Graphics]::FromImage($small)
$sg.InterpolationMode = 'HighQualityBicubic'; $sg.SmoothingMode = 'AntiAlias'; $sg.PixelOffsetMode = 'HighQuality'
$sg.DrawImage($bmp, 0, 0, 400, 400); $sg.Dispose()
$small.Save((Join-Path $out "logo-400.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$small.Dispose(); $bmp.Dispose()
Write-Host "Wrote logo-1024.png and logo-400.png"
