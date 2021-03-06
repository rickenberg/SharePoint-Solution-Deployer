###############################################################################
# SharePoint Solution Deployer (SPSD) Extension for SharePoint Features
# Version          : 1.0.0.0
# Creator          : René Hézser
# License          : MS-PL
# File             : Features.ps1
###############################################################################

function Execute-FeaturesExtension($parameters, [System.Xml.XmlElement]$data, [string]$extId, [string]$extensionPath){
	$featuresNode = $data.FirstChild
	foreach($featureNode in $featuresNode.ChildNodes){
		if ($featureNode.LocalName -ne 'Feature') { continue }
		
		$feature = Get-SPFeature -Limit ALL | Where-Object {$_.DisplayName -eq $featureNode.Name}
		if ($feature -eq $null){ 
			#throw New-Object Exception('A feature with the name '+$featureNode.Name+' cannot be found') 
			Log -message ('Execute-FeatureExtension: A feature with the name '+$featureNode.Name+' cannot be found') -type $SPSD.LogTypes.Error
			break
		}
		Log -message ('Working on feature "'+$feature.DisplayName+'"') -type $SPSD.LogTypes.Information
		Execute-FeatureAction $feature $featureNode.Urls
	}
}

function Execute-FeatureAction ([Microsoft.SharePoint.Administration.SPFeatureDefinition]$feature, [System.Xml.XmlElement]$urlNodes) {
	foreach ($urlNode in $urlNodes.ChildNodes) {
		if ($urlNode.LocalName -ne 'Url') { continue }

		$action = $urlNode.Attributes['Action'].Value
		[bool]$force = $false
		$result = [Boolean]::TryParse($urlNode.Attributes['Force'].Value, [ref] $force)
		$url = $urlNode.InnerText
		
		if ($action -eq 'Enable') {
			Execute-EnableFeature $feature $force $url
		} elseif ($action -eq 'Disable') {
			Execute-DisableFeature $feature $force $url
		} else {
			throw New-Object NotImplementedException('The feature action '+$action+' is not yet implemented.')
		}
	}
}

function Execute-EnableFeature([Microsoft.SharePoint.Administration.SPFeatureDefinition]$feature, [bool]$force, [string]$url) {
	Log -message ('Installing/Enabling feature "'+$feature.DisplayName+'"') -type $SPSD.LogTypes.Normal
	Log -message ('on '+$url+'...') -type $SPSD.LogTypes.Normal -NoNewLine
	if ($force -ne $true){
		# if force is disabled, check if the feature is already activated
		if ($feature.Scope -eq [Microsoft.SharePoint.SPFeatureScope]::Farm) {
			$enabled = Get-SPFeature -Farm | Where-Object {$_.Id -eq $feature.Id}
		} elseif ($feature.Scope -eq [Microsoft.SharePoint.SPFeatureScope]::WebApplication) {
			$enabled = Get-SPFeature -WebApplication $url | Where-Object {$_.Id -eq $feature.Id}
		} elseif ($feature.Scope -eq [Microsoft.SharePoint.SPFeatureScope]::Site) {
			$enabled = Get-SPFeature -Site $url | Where-Object {$_.Id -eq $feature.Id}
		} elseif ($feature.Scope -eq [Microsoft.SharePoint.SPFeatureScope]::Web) {
			$enabled = Get-SPFeature -Web $url | Where-Object {$_.Id -eq $feature.Id}
		}
		if ($enabled) {
			Log -message "Done (Already installed/enabled)" -type $SPSD.LogTypes.Success -NoIndent
			return
		}
	}

	if ($feature.Scope -eq [Microsoft.SharePoint.SPFeatureScope]::Farm) {
		# Farm features do not get Enabled. They just get installed
		Install-SPFeature -Path $feature.Name -Force $force -Confirm:$false
	} else {
		Enable-SPFeature -Identity $feature.Id -Force:$force -Url $url -Confirm:$false
	}
	
	Log -message 'Done' -type $SPSD.LogTypes.Success -NoIndent
}

function Execute-DisableFeature([Microsoft.SharePoint.Administration.SPFeatureDefinition]$feature, [bool]$force, [string]$url) {
	Log -message ('Uninstalling/Disabling feature "'+$feature.DisplayName+'"') -type $SPSD.LogTypes.Normal
	Log -message ('on '+$url+'...') -type $SPSD.LogTypes.Normal -NoNewLine

	if ($force -ne $true){
		# if force is disabled, check if the feature is already activated
		if ($feature.Scope -eq [Microsoft.SharePoint.SPFeatureScope]::Farm) {
			$enabled = Get-SPFeature -Farm | Where-Object {$_.Id -eq $feature.Id}
		} elseif ($feature.Scope -eq [Microsoft.SharePoint.SPFeatureScope]::WebApplication) {
			$enabled = Get-SPFeature -WebApplication $url | Where-Object {$_.Id -eq $feature.Id}
		} elseif ($feature.Scope -eq [Microsoft.SharePoint.SPFeatureScope]::Site) {
			$enabled = Get-SPFeature -Site $url | Where-Object {$_.Id -eq $feature.Id}
		} elseif ($feature.Scope -eq [Microsoft.SharePoint.SPFeatureScope]::Web) {
			$enabled = Get-SPFeature -Web $url | Where-Object {$_.Id -eq $feature.Id}
		}
		if ($enabled -eq $false) {
			Log -message 'Done (not enabled)' -type $SPSD.LogTypes.Success -NoIndent
			return
		}
	}

	if ($feature.Scope -eq [Microsoft.SharePoint.SPFeatureScope]::Farm) {
		# Farm features do not get Enabled. They just get installed
		Uninstall-SPFeature -Path $feature.Name -Force $force -Confirm:$false
	} else {
		Disable-SPFeature -Identity $feature.Id -Force:$force -Url $url -Confirm:$false
	}
	
	Log -message 'Done' -type $SPSD.LogTypes.Success -NoIndent
}