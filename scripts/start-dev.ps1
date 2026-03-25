Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$libsDir = Join-Path $repoRoot 'libs'
$stylesMain = Join-Path $repoRoot 'css/main.scss'
$stylesBundle = Join-Path $repoRoot 'css/all.bundle.css'
$stylesDestination = Join-Path $repoRoot 'css/all.css'

function Assert-Path {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [string] $Hint = ''
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        $message = "Missing required path: $Path"

        if ($Hint) {
            $message += " ($Hint)"
        }

        throw $message
    }
}

function Copy-RequiredFile {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [string] $Destination
    )

    Assert-Path -Path $Path
    Copy-Item -LiteralPath $Path -Destination $Destination -Force
}

function Copy-RequiredGlob {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Pattern,

        [Parameter(Mandatory = $true)]
        [string] $Destination
    )

    $matches = Get-ChildItem -Path $Pattern -ErrorAction SilentlyContinue

    if (-not $matches) {
        throw "No files matched pattern: $Pattern"
    }

    Copy-Item -LiteralPath $matches.FullName -Destination $Destination -Force
}

function Copy-RequiredDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [string] $Destination
    )

    Assert-Path -Path $Path
    Copy-Item -LiteralPath $Path -Destination $Destination -Recurse -Force
}

$sass = Join-Path $repoRoot 'node_modules/.bin/sass.cmd'
$cleanCss = Join-Path $repoRoot 'node_modules/.bin/cleancss.cmd'
$webpack = Join-Path $repoRoot 'node_modules/.bin/webpack.cmd'

Assert-Path -Path $sass -Hint 'Run npm.cmd install first.'
Assert-Path -Path $cleanCss -Hint 'Run npm.cmd install first.'
Assert-Path -Path $webpack -Hint 'Run npm.cmd install first.'

if (Test-Path -LiteralPath $libsDir) {
    Remove-Item -LiteralPath $libsDir -Recurse -Force
}

New-Item -ItemType Directory -Path $libsDir | Out-Null

Copy-RequiredFile -Path (Join-Path $repoRoot 'node_modules/@jitsi/rnnoise-wasm/dist/rnnoise.wasm') -Destination $libsDir
Copy-RequiredGlob -Pattern (Join-Path $repoRoot 'react/features/stream-effects/virtual-background/vendor/tflite/*.wasm') -Destination $libsDir
Copy-RequiredGlob -Pattern (Join-Path $repoRoot 'react/features/stream-effects/virtual-background/vendor/models/*.tflite') -Destination $libsDir
Copy-RequiredGlob -Pattern (Join-Path $repoRoot 'node_modules/lib-jitsi-meet/dist/umd/lib-jitsi-meet.*') -Destination $libsDir
Copy-RequiredFile -Path (Join-Path $repoRoot 'node_modules/@matrix-org/olm/olm.wasm') -Destination $libsDir
Copy-RequiredGlob -Pattern (Join-Path $repoRoot 'node_modules/@tensorflow/tfjs-backend-wasm/dist/*.wasm') -Destination $libsDir
Copy-RequiredDirectory -Path (Join-Path $repoRoot 'node_modules/@jitsi/excalidraw/dist/excalidraw-assets-dev') -Destination $libsDir

$faceModelsDir = Join-Path $repoRoot 'node_modules/@vladmandic/human-models/models'
$faceModelFiles = @(
    'blazeface-front.bin',
    'blazeface-front.json',
    'emotion.bin',
    'emotion.json'
)

foreach ($faceModelFile in $faceModelFiles) {
    Copy-RequiredFile -Path (Join-Path $faceModelsDir $faceModelFile) -Destination $libsDir
}

& $sass $stylesMain $stylesBundle

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

$minifiedCss = & $cleanCss --skip-rebase $stylesBundle

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($stylesDestination, ($minifiedCss -join [Environment]::NewLine), $utf8NoBom)
Remove-Item -LiteralPath $stylesBundle -Force

Push-Location $repoRoot

try {
    & $webpack serve --mode development --progress
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
