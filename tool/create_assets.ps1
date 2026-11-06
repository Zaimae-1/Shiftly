# Course Step 2 names the assets but supplies no download links.
# Generate simple local menu icons and a Lottie scanning ring.
Add-Type -AssemblyName System.Drawing
$assetRoot = Join-Path $PSScriptRoot '..\assets'
foreach ($iconName in @('ic_absen', 'ic_leave', 'ic_history')) {
    $bitmap = [System.Drawing.Bitmap]::new(192, 192)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $pen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(79, 70, 229), 9)
    $pen.StartCap = $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    switch ($iconName) {
        'ic_absen' {
            $graphics.DrawRectangle($pen, 25, 42, 142, 112)
            $graphics.DrawEllipse($pen, 65, 67, 62, 62)
            $graphics.DrawLine($pen, 53, 42, 65, 25)
            $graphics.DrawLine($pen, 65, 25, 127, 25)
            $graphics.DrawLine($pen, 127, 25, 139, 42)
        }
        'ic_leave' {
            $graphics.DrawRectangle($pen, 42, 28, 108, 136)
            $graphics.DrawLine($pen, 69, 61, 123, 61)
            $graphics.DrawLine($pen, 96, 84, 96, 136)
            $graphics.DrawLine($pen, 70, 110, 122, 110)
        }
        'ic_history' {
            $graphics.DrawEllipse($pen, 28, 28, 136, 136)
            $graphics.DrawLine($pen, 96, 52, 96, 96)
            $graphics.DrawLine($pen, 96, 96, 128, 118)
        }
    }
    $bitmap.Save((Join-Path $assetRoot "images\$iconName.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $pen.Dispose()
    $graphics.Dispose()
    $bitmap.Dispose()
}
@'
{
  "v":"5.7.4","fr":30,"ip":0,"op":60,"w":240,"h":240,
  "nm":"Face scanner ring","ddd":0,"assets":[],
  "layers":[{
    "ddd":0,"ind":1,"ty":4,"nm":"Scanning ring","sr":1,
    "ks":{"o":{"a":0,"k":100},"r":{"a":1,"k":[{"t":0,"s":[0],"e":[360],"o":{"x":0.333,"y":0.333},"i":{"x":0.667,"y":0.667}},{"t":60,"s":[360]}]},"p":{"a":0,"k":[120,120,0]},"a":{"a":0,"k":[0,0,0]},"s":{"a":0,"k":[100,100,100]}},
    "shapes":[{"ty":"el","p":{"a":0,"k":[0,0]},"s":{"a":0,"k":[204,204]},"d":1,"nm":"Ring"},{"ty":"st","c":{"a":0,"k":[0.31,0.275,0.898,1]},"o":{"a":0,"k":100},"w":{"a":0,"k":5},"lc":2,"lj":2,"d":[{"n":"d","v":{"a":0,"k":44}},{"n":"g","v":{"a":0,"k":16}}],"nm":"Ring stroke"}],
    "ip":0,"op":60,"st":0,"bm":0
  }]
}
'@ | Set-Content -LiteralPath (Join-Path $assetRoot 'raw\face_id_ring.json') -Encoding utf8
