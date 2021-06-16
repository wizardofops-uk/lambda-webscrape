#Requires -Modules AWS.Tools.Common,AWS.Tools.S3,Microsoft.PowerShell.Archive

function Move-S3 {
  Param (
    [Switch]$Upload,
    [Switch]$Download,
    [Parameter(Mandatory)][String]$Bucket,
    [Parameter(Mandatory,ParameterSetName='File')][String]$Key,
    [Parameter(Mandatory,ParameterSetName='File')][String]$File,
    [Parameter(Mandatory,ParameterSetName='Folder')][String]$KeyPrefix,
    [Parameter(Mandatory,ParameterSetName='Folder')][String]$Folder,
    [String]$filepath = "/tmp"
  )
  Try {
    If ($Upload) {
      If ($Folder) {
        Write-S3Object -BucketName $bucket -KeyPrefix $KeyPrefix -Folder $Folder -Recurse
        Write-Information "Uploaded $Folder to S3 $Bucket/$KeyPrefix"
        Remove-Item -Path $filepath/* -Recurse -Force
      } Else {
        Write-S3Object -BucketName $Bucket -Key $Key -File $filepath/$File
        Write-Information "Uploaded $File to S3 $Bucket/$Key"
        Remove-Item -Path $filepath/$File -Force
      }
    } ElseIf ($Download) {
      If ($Folder) {
        Read-S3Object -BucketName $Bucket -KeyPrefix $KeyPrefix -Folder $Folder
        Write-Information "Downloaded $Bucket/$KeyPrefix to $Folder"
      } Else {
        Read-S3Object -BucketName $Bucket -Key $Key -File $filepath/$File
        Write-Information "Downloaded $Bucket/$Key to $File"
      }
      
    }
  } Catch {
    Throw $_
  } 
}

Function Download-File {
  Param (
    [Parameter(Mandatory=$true)][String]$url,
    [Parameter(Mandatory=$true)][String]$filename,
    [String]$filepath = "/tmp"
  )
  Try {
    Invoke-WebRequest -Uri $url -OutFile $filepath/$filename 
    Write-Information "Downloaded: $filename Size: $((Get-Item $filepath/$filename).length/1mb)"
  } Catch {
    Throw $_
  }
}

Function Unzip-File {
  Param (
    [Parameter(Mandatory=$true)][String]$filename,
    [Parameter(Mandatory=$true)][String]$bucket,
    [String]$filepath = "/tmp"
  )
  Try {
    Expand-Archive -Path $filepath/$filename -DestinationPath $filepath/extracted_$filename
    Move-S3 -Bucket $bucket -KeyPrefix $filename -Folder $filepath/extracted_$filename -Upload
  } Catch {
    Throw $_
  }
}

Function Scrape-Website {
  Param (
    [Parameter(Mandatory=$true)][String]$url,
    [Parameter(Mandatory=$true)][String]$pattern
  )
  Write-Verbose "Getting Base URL"
  $surl = $url.split("/")
  $baseurl = $surl[0] + "//" + $surl[2]

  Write-Verbose "Scraping URL"
  $page = Invoke-WebRequest $url

  Write-Verbose "Building Output"
  $arr = @()
  $page.links.href | % {
    If ($_ -match $pattern) {
      If ($_ -match "://") {
        Write-Verbose "$_ is a full URL"
        $arr += $_
      } Else {
        Write-Verbose "$_ is a relative URL, adding base URL"
        $arr += $baseurl + "/" + $_
      }
    } Else {
      Write-Warning "NOMATCH: $_"
    }
  }
  Write-Information "Scraped Links for $url"
  Return $arr
}

# Begin Main
$InformationPreference = "Continue"
Write-Information "Assume Lambda and load from env"
$url = $env:URL
$pattern = $env:PATTERN
$verbose = $env:VERBOSITY
$bucket = $env:BUCKETNAME
$unzip = $env:UNZIP

If (!$url) {Throw "Missing url!"}
If (!$pattern) {Throw "Missing pattern!"}
If (!$bucket) {Throw "Missing bucket!"}

If ($verbose -eq "true") {
  $VerbosePreference = "Continue"
  $ProgressPreference = "Continue"
} Else {
  $VerbosePreference = "SilentlyContinue"
  $ProgressPreference = "SilentlyContinue"
}

$links = Scrape-Website -url $url -pattern $pattern
$links | % {
  $filename = $_.split("/")[3]
  Try {
    Download-File -url $_ -filename $filename
  } Catch {
    Throw "Download failed $filename : ERROR: $_"
  }
  If ($unzip -eq "true" -and $filename -match ".zip$") {
    Try {
      Unzip-File -filename $filename -bucket $bucket
    } Catch {
      Throw "S3 Upload failed $filename : ERROR: $_"
    }
  } Else {
    Try {
      Move-S3 -Bucket $bucket -Key $filename -File $filename -Upload
    } Catch {
      Throw "S3 Upload failed $filename : ERROR: $_"
    }
  }
}

Write-Information "COMPLETED: Download of Data @ $(Get-Date)"