<#
-Functions-
OktaAppSearch
Get-OktaUserID
Get-OktaAppName
Get-OktaUserAppName
Set-OktaUserAppName
Get-OktaUserEnrolledFactors
Get-AllOktaApps
Get-OktaAppADGroup
#>

$baseURL = 'https://company.okta.com/api/v1'
$token = 'companyToken'
$domain = 'companyDomain'

$headers = @{"Accept" = "application/json"; "Content-Type" = "application/json";
    "Authorization" = "SSWS ${token}"
}

# Get a list of all the active apps, saves a bit of time as that function is slow.
$allApps = Get-AllOktaApps

function OktaAppSearch ($appName) {
    
    $appInfo = $allApps|Where-Object Label -like "*$appName*"|Select-Object Label,ID
    if (!$appInfo){
        Write-host -ForegroundColor Red "Could not find $appName. Please try again."
    }
    return $appInfo
}
function Get-OktaUserID ($userName) {
    $Uri = ($baseURL +'/users/' + $userName)
    $response = Invoke-RestMethod -Headers $headers -Method Get -Uri $Uri
    return $response.id
    #$response.profile.login
}

function Get-OktaAppName {
    param (
        [parameter(ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True)]     
        [string[]]$appID
    )
    $Uri = ($baseURL +'/apps/' + $appID)
    $response = Invoke-RestMethod -Headers $headers -Method Get -Uri $Uri
    return $response.label
}

function Get-OktaUserAppName {
    param (
        [parameter(ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True)]     
        $appID,
        $userName
        
    )

    $userName = Get-OktaUserID $userName
    $Uri = ($baseURL + '/apps/' + $appID + '/users/' + $userName)
    $response = Invoke-RestMethod -Headers $headers -Method Get -Uri $Uri
    return $response.credentials.userName

}
function Set-OktaUserAppName {
    param (
        [parameter(ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True)]     
        $appID,
        $userName,
        $appName      
    )

    $data = @{}
    $data['credentials'] = @{}
    $data.credentials['userName'] = $appName
    $body = ConvertTo-Json $data

    $userName = Get-OktaUserID $userName
    $Uri = ($baseURL + '/apps/' + $AppID + '/users/' + $userName)
    $response = Invoke-RestMethod -Headers $headers -Method Post -Uri $Uri -Body $Body
    return $response.credentials.userName

}
function Get-OktaUserEnrolledFactors ($userName) {
    $userID = Get-OktaUserID $userName
    $Uri = ($baseURL +'/users/' + $UserID + '/factors')
    $response = Invoke-RestMethod -Headers $headers -Method Get -Uri $Uri
    
    $response.factorType
    $response.id
    if ($response.factorType -eq 'sms')
    {return $response.profile.phoneNumber}
}

function Invoke-PagedMethod ($Url) {
  
    try {
        $response = Invoke-WebRequest $Url -Method GET -Headers $headers
        $links = @{}
        if ($response.Headers.Link) {
            foreach ($header in $response.Headers.Link.split(",")) {
                if ($header -match '<(.*)>; rel="(.*)"') {
                    $links[$matches[2]] = $matches[1]
                }
            }
        }
        @{objects = ConvertFrom-Json $response.content; nextUrl = $links.next}
    }
    catch {
        Throw $_
    }
}

function Get-AllOktaApps {

    $Apps = @()
    $res = @{"nextURL" = "https://company.okta.com/api/v1/apps"}
    while ($true) {
        try {
            if ($res.nextURL -eq $Null) {
                write-verbose "finished retireveAllOktaApps function"
                break;
            }
            $res = Invoke-PagedMethod –Url $res.nextURL -Headers $headers -Method GET
            if ($res.objects) {
                $Apps += $res.objects
            }
            write-verbose "retrieved $($Apps.Count) Apps..."
        }
        catch {
            Throw "failed to retrieve Apps from Okta: $_"
        }
    }
    foreach ($ap in $apps) {
        if ($ap.status -eq 'ACTIVE' -and $ap.label -ne $domain) {
            $result = $ap|Select-Object label, id, signOnMode, created
            $result
        }

    }
}

function Get-OktaAppADGroup ($AppID){
    
    $Uri = ($baseURL + '/apps/' + $AppID + '/groups')
    $response = Invoke-RestMethod -Headers $headers -Method Get -Uri $Uri
    $appName = Get-OktaAppName $AppID
    $Object = New-Object psobject
    $Object| add-member Noteproperty AppName $appName
    $Groups = @()
    
    foreach ($groupID in $response.id) {
        $Uri = ($baseURL + '/groups/' + $groupID)
        $response = Invoke-RestMethod -Headers $headers -Method Get -Uri $Uri
        $Groups += $response.profile.samAccountName
        

    }$Object| add-member NoteProperty ADGroups $Groups
    return $Object

}
