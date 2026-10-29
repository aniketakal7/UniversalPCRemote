<#
.SYNOPSIS
    Signs the Universal PC Remote executable using a local Authenticode certificate.
.DESCRIPTION
    Uses a self-signed code signing certificate and adds a DigiCert timestamp
    so the signature remains valid indefinitely.
#>

$cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert | Where-Object { $_.Subject -like "*Universal PC Remote*" } | Select-Object -First 1

if (-not $cert) {
    Write-Host "Creating a new Code Signing certificate for Universal PC Remote..." -ForegroundColor Cyan
    $cert = New-SelfSignedCertificate `
        -Type CodeSigningCert `
        -Subject "CN=Universal PC Remote, O=Aniket Akal" `
        -CertStoreLocation "Cert:\CurrentUser\My" `
        -NotAfter (Get-Date).AddYears(5)
}

$targets = @(
    "$PSScriptRoot\..\dist\windows\standalone\UniversalPCRemote.exe",
    "$PSScriptRoot\..\windows_companion\bin\Debug\net8.0-windows\UniversalPCRemote.exe"
)

foreach ($file in $targets) {
    if (Test-Path $file) {
        Write-Host "Signing $file ..." -ForegroundColor Yellow
        Set-AuthenticodeSignature -FilePath $file -Certificate $cert -TimestampServer "http://timestamp.digicert.com" | Out-Null
        Write-Host "  -> Successfully signed with DigiCert timestamp." -ForegroundColor Green
    }
}

# Export public certificate
$exportPath = "$PSScriptRoot\..\dist\windows\UniversalPCRemote.cer"
[System.IO.File]::WriteAllBytes($exportPath, $cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert))
Write-Host "Public certificate exported to: dist\windows\UniversalPCRemote.cer" -ForegroundColor Green
