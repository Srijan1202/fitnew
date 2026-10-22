<#
.SYNOPSIS
  FITOS beta on AWS (ADR-025): store one server setting in Parameter Store,
  encrypted. The value is typed into a hidden prompt (or read from a file)
  and goes to AWS through a temporary file that is deleted at once — never
  a command line, the shell history or the chat.

.DESCRIPTION
  API settings land in /fitos/beta/env/<Name> and reach the container as
  environment variables on the next release (deploy.ps1). A file lands in
  /fitos/beta/files/<Name>.

.EXAMPLE
  .\scripts\aws\set-parameter.ps1 -Name GEMINI_API_KEY                 # hidden prompt
  .\scripts\aws\set-parameter.ps1 -Name FIREBASE_PROJECT_ID -Value fitos-dev-3208b
  .\scripts\aws\set-parameter.ps1 -FirebaseCredential .\fitos-aws-wif.json
#>
[CmdletBinding(DefaultParameterSetName = 'env')]
param(
  [Parameter(ParameterSetName = 'env', Mandatory = $true)][ValidatePattern('^[A-Z][A-Z0-9_]*$')][string]$Name,
  # Only for values that are not secret (a project id, a model name, a limit).
  [Parameter(ParameterSetName = 'env')][string]$Value,
  [Parameter(ParameterSetName = 'file', Mandatory = $true)][string]$FirebaseCredential,
  [string]$AwsProfileName = 'fitos',
  [string]$Region = 'ap-south-1'
)

. (Join-Path $PSScriptRoot 'common.ps1')
Initialize-Aws $AwsProfileName $Region

if ($PSCmdlet.ParameterSetName -eq 'file') {
  $path = (Resolve-Path $FirebaseCredential).Path
  $text = [IO.File]::ReadAllText($path)
  $kind = ($text | ConvertFrom-Json).type
  if ($kind -notin 'external_account', 'service_account') { throw "Not a Google credential file (type '$kind')." }
  $parameterName = '/fitos/beta/files/firebase-credential.json'
} else {
  if ($PSBoundParameters.ContainsKey('Value')) {
    $text = $Value
  } else {
    $secure = Read-Host -AsSecureString "Value for $Name (hidden)"
    $text = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
  }
  if ([string]::IsNullOrWhiteSpace($text)) { throw 'Empty value: nothing stored.' }
  $parameterName = "/fitos/beta/env/$Name"
}

$file = Join-Path $env:TEMP "fitos-param-$([guid]::NewGuid()).json"
try {
  $body = @{ Name = $parameterName; Type = 'SecureString'; Value = $text; Overwrite = $true } | ConvertTo-Json -Compress
  [IO.File]::WriteAllText($file, $body)
  Invoke-Aws ssm put-parameter --cli-input-json "file://$file" | Out-Null
} finally {
  Remove-Item $file -ErrorAction SilentlyContinue
  $text = $null
}
Write-Host "Stored $parameterName. It takes effect on the next release (deploy.ps1)."
