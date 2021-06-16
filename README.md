# Overview
This is a small function to scrape a website and download the links present on the page matching the desired regex pattern.

## Lambda Usage
The following environment variables should be set on the lamba function  

| Key | Value | Description | Example |
|---|---|---|---|
| URL | string | Full URL which contains download links | https://contoso.com/download.html |
| PATTERN | string | Regex Pattern to identify the links | Data.* |
| VERBOSITY | boolean | Specify if verbose output is enabled | true/false |
| BUCKETNAME | string | Name of the s3 bucket | mydownloadtarget |
| UNZIP | boolean | Specify if zipped files should be unzipped before upload | true/false |
  
The function can be ran by sending a blank `{}` event to the function.  
for details on creating and testing a basic lambda function, see:  
https://docs.aws.amazon.com/lambda/latest/dg/getting-started-create-function.html  
  
## Publishing the script to lambda
AWSLambdaPSCore is required for the commands below  
`Install-Module AWSLambdaPSCore -Scope CurrentUser`
  
Ensure AWS credentials are setup  
`Set-AWSCredential -AccessKey AKIAEXAMPLEKEY -SecretKey MYEXAMPLEKEY -StoreAs default`  
for details on how to generate keys, see:  
https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html#Using_CreateAccessKey  
  
The following command can be used to package and publish the file  
`Publish-AWSPowerShellLambda -ScriptPath .\lambda-webscrape.ps1 -Name lambda-webscrape -Region eu-west-1`  
  
The following command can be used to package the function for use in a pipeline  
`New-AWSPowerShellLambdaPackage -ScriptPath ./lambda-webscrape.ps1 -OutputPackage ./lambda-webscrape.zip`  
  
The lambda handler for the function will be  
`lambda-webscrape::lambda_webscrape.Bootstrap::ExecuteFunction`  