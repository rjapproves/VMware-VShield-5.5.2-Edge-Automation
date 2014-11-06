## Edge Appliance Deploy and configuration. Powershell 4.0 + PowerCLI 5.8 release 1
## Please update edge-config.xml to suit your environment
## Created by Ranjit RJ Singh - Zero liablity assumed run at your own risk
## www.rjapproves.com @rjapproves
##
##
##

Add-PSSnapin Vmware.vimautomation.core
Add-PSSnapin VMware.VimAutomation.Vds
Set-StrictMode -Version 2.0

#Reading the XML and copying all the info.

$xml = [XML](Get-Content edge-config.xml)

$vsmip = $xml.MasterConfig.vShieldAppConfig.vshield_ip
$edge_app_name = $xml.MasterConfig.Edgeconfig.Edge_app_name
$edge_app_description = $xml.MasterConfig.Edgeconfig.Edge_app_description
$core_root_password = $xml.MasterConfig.Edgeconfig.Edge_password

$vcenteruser = $xml.MasterConfig.vcenterconfig.vcenteruser
$vcenterpassword = $xml.MasterConfig.vcenterconfig.vcenterpassword
$vcenter = $xml.MasterConfig.vcenterconfig.vcenterfqdn
$cluster_name = $xml.MasterConfig.vcenterconfig.Edge_cluster
$datacentername = $xml.MasterConfig.vcenterconfig.Edge_datacenter
$internalportgroupname = $xml.MasterConfig.vcenterconfig.InternalDVportgroup_name
$externalportgroupname = $xml.MasterConfig.vcenterconfig.ExternalDVportgroup_name 
$heartbeatportgroupname = $xml.MasterConfig.vcenterconfig.HeartbeatDVportgroup_name
$Edge_datastore = $xml.MasterConfig.vcenterconfig.Edge_datastore

$INTERNAL_network = $xml.MasterConfig.routes.INTERNAL_network
$INTERNAL_network2 = $xml.MasterConfig.routes.INTERNAL_network2
$gatewayaddr = $xml.MasterConfig.routes.gatewayaddr
$nexthop = $xml.MasterConfig.routes.nexthop

$vcd_INTERNAL_web_vip = $xml.MasterConfig.EdgeIPConfig.VCD_INTERNAL_web_vip
$vcd_INTERNAL_console_vip = $xml.MasterConfig.EdgeIPConfig.VCD_INTERNAL_console_vip
$vcenter_INTERNAL_web_vip = $xml.MasterConfig.EdgeIPConfig.vcenter_INTERNAL_web_vip
$vcenter_INTERNAL_websvcs_vip = $xml.MasterConfig.EdgeIPConfig.vcenter_INTERNAL_websvcs_vip
$vcd_exnet_console_vip = $xml.MasterConfig.EdgeIPConfig.vcd_exnet_console_vip
$vcd_exnet_web_vip = $xml.MasterConfig.EdgeIPConfig.vcd_exnet_web_vip
$external_edge_ip = $xml.MasterConfig.EdgeIPConfig.Edge_exnet_ip
$vcenter_exnet_ip = $xml.MasterConfig.EdgeIPConfig.vcenter_exnet_ip
$vcd_exnet_console_ip1 = $xml.MasterConfig.EdgeIPConfig.vcd_exnet_console_ip1
$vcd_exnet_console_ip2 = $xml.MasterConfig.EdgeIPConfig.vcd_exnet_console_ip2
$vcd_exnet_web_ip1 = $xml.MasterConfig.EdgeIPConfig.vcd_exnet_web_ip1
$vcd_exnet_web_ip2 = $xml.MasterConfig.EdgeIPConfig.vcd_exnet_web_ip2

$vshieldDefaultUser = $xml.MasterConfig.vShieldAppConfig.vshielduser
$vShieldDefaultPass = $xml.MasterConfig.vShieldAppConfig.vshieldpass

$DC_Terminal_Ipaddress = $xml.MasterConfig.EdgeIPConfig.DC_terminal_ip
$DC_Name = $xml.MasterConfig.EdgeIPConfig.DC_Name

#vShield API Url
$vsm_edge_url = "https://"+$vsmip+"/api/3.0/edges"

#Building the headers
$auth = $vshieldDefaultUser + ':' + $vShieldDefaultPass
$Encoded = [System.Text.Encoding]::UTF8.GetBytes($auth)
$EncodedPassword = [System.Convert]::ToBase64String($Encoded)
$headers = @{"Authorization"="Basic $($EncodedPassword)";}

#Decalre the PUT function
Function Calling-Put($url,$Body){
try {
Invoke-RestMethod -Headers $headers -Uri $url -Body $Body -Method Put -ContentType Application/xml 
} 
            catch { $_.Exception
            Write-Host "Put Failed at - " $url }
}

#Declare the POST function
Function Calling-Post($url,$Body){
try {
Invoke-RestMethod -Headers $headers -Uri $url -Body $Body -Method Post -ContentType Application/xml 
} 
            catch { $_.Exception 
            Write-Host "Post Failed at - " $url }              
}

#Connect to the vcenter where vSM will be deployed
Write-host "Connecting to vcenter..."
connect-viserver -server $vcenter -protocol https -username $vcenteruser -password $vcenterpassword | Out-Null

#Getting the MOID for datacenter, resourcepool, networks and datastore
$datastore_full_id = get-cluster $cluster_name | Get-Datastore $edge_datastore | Select-Object -ExpandProperty Id | Out-String
$resource_full_id = Get-ResourcePool -Location $cluster_name | Select-Object -ExpandProperty Id | Out-String 
$datacenter_full_id = get-datacenter $datacentername | Select-Object -ExpandProperty Id | Out-String
$internal_network_full_id = get-vdportgroup -Name $internalportgroupname | Select-Object -ExpandProperty Id | Out-String
$external_network_full_id = get-vdportgroup -Name $externalportgroupname | Select-Object -ExpandProperty Id | Out-String
$heartbeat_network_full_id = Get-VDPortgroup -Name $heartbeatportgroupname | Select-Object -ExpandProperty Id | Out-String

#Cleaning up and prepping the variables
$datastoremoid = $datastore_full_id.Replace("Datastore-datastore","datastore")
$resourcemoid = $resource_full_id.Replace("ResourcePool-resgroup","resgroup")
$datacentermoid= $datacenter_full_id.Replace("Datacenter-datacenter","datacenter")
$internal_networkmoid = $internal_network_full_id.Replace("DistributedVirtualPortgroup-dvportgroup","dvportgroup")
$external_networkmoid = $external_network_full_id.Replace("DistributedVirtualPortgroup-dvportgroup","dvportgroup")
$heartbeat_networkmoid = $heartbeat_network_full_id.Replace("DistributedVirtualPortgroup-dvportgroup","dvportgroup")

$datastoremoid = $datastoremoid.Trim()
$resourcemoid = $resourcemoid.Trim()
$datacentermoid = $datacentermoid.Trim()
$internal_networkmoid = $internal_networkmoid.Trim()
$external_networkmoid = $external_networkmoid.Trim()
$heartbeat_networkmoid = $heartbeat_networkmoid.Trim()

#Ignore selfsigned cert
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

#Function to deploy the Edge    
Function Deploy-Edge () {
    $Body = @"
<edge>
<datacenterMoid>${datacentermoid}</datacenterMoid>
<name>${edge_app_name}</name> 
<description>${edge_app_description}</description> 
<tenant>org1</tenant>
<fqdn>${edge_app_name}</fqdn> 
<vseLogLevel>info</vseLogLevel>
    <appliances>
        <applianceSize>large</applianceSize> 
        <appliance>
        <resourcePoolId>${resourcemoid}</resourcePoolId>
        <datastoreId>${datastoremoid}</datastoreId>
        </appliance> 
    </appliances>
        <vnics> 
<vnic>
    <index>0</index>
    <label>vNic0</label>
    <isConnected>true</isConnected> 
    <name>${externalportgroupname}</name> 
    <type>uplink</type>
    <portgroupId>${external_networkmoid}</portgroupId>
    <portgroupName>${externalportgroupname}</portgroupName>
    <addressGroups>
        <addressGroup> 
        <primaryAddress>${external_edge_ip}</primaryAddress> 
        <secondaryAddresses>
        <ipAddress>${vcd_exnet_web_vip}</ipAddress>
        <ipAddress>${vcd_exnet_console_vip}</ipAddress>
        </secondaryAddresses>
        <subnetMask>255.255.252.0</subnetMask>
    </addressGroup>
    </addressGroups>
</vnic> 
<vnic>
    <index>1</index>
    <label>vNic1</label>
    <isConnected>true</isConnected> 
    <name>${internalportgroupname}</name> 
    <type>uplink</type>
    <portgroupId>${internal_networkmoid}</portgroupId>
    <portgroupName>${internalportgroupname}</portgroupName>
    <addressGroups>
        <addressGroup> 
        <primaryAddress>${vcd_INTERNAL_web_vip}</primaryAddress> 
        <secondaryAddresses>
        <ipAddress>${vcd_INTERNAL_console_vip}</ipAddress>
        <ipAddress>${vcenter_INTERNAL_web_vip}</ipAddress>
        <ipAddress>${vcenter_INTERNAL_websvcs_vip}</ipAddress>
        </secondaryAddresses>
        <subnetMask>255.255.248.0</subnetMask>
    </addressGroup>
    </addressGroups>
</vnic> 
<vnic>
    <index>2</index>
    <label>vNic2</label>
<isConnected>true</isConnected>
    <name>${heartbeatportgroupname}</name> 
    <type>Internal</type>
    <portgroupId>${heartbeat_networkmoid}</portgroupId>
    <portgroupName>${heartbeatportgroupname}</portgroupName>
    <addressGroups>
    </addressGroups>
</vnic> 
</vnics> 
<cliSettings>
    <userName>admin</userName> 
    <password>${core_root_password}</password> 
    <remoteAccess>true</remoteAccess> 
</cliSettings>
<autoConfiguration> 
    <enabled>true</enabled>
    <rulePriority>high</rulePriority> 
</autoConfiguration>
</edge>
"@
   Calling-Post -url $vsm_edge_url -Body $Body
}


#Function to grab the Edge ID after its deployed - this is needed to configure LB, FW and Edge HA
Function Get-Edge-Id(){
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
$auth = 'Basic ' + [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($vshieldDefaultUser+':'+$vShieldDefaultPass))

#GET all edges
$req = [System.Net.WebRequest]::Create($vsm_edge_url)
$req.Method ="GET"
$req.Headers.add("AUTHORIZATION", $auth);
$resp = $req.GetResponse()
$reader = new-object System.IO.StreamReader($resp.GetResponseStream())
[xml]$xmloutput = $reader.ReadToEnd()
 
#here you find all edges:
foreach($edge in $xmloutput.pagedEdgeList.edgePage.edgeSummary){
if($edge.name -eq $edge_app_name){
       return $edge.objectId
       }
    }
}

#Function to check if the Edge is in "deployed" state
Function Check-Edge-State(){
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
$auth1 = 'Basic ' + [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($vshieldDefaultUser+':'+$vShieldDefaultPass))

#GET all edges
$req1 = [System.Net.WebRequest]::Create($vsm_edge_url)
$req1.Method ="GET"
$req1.Headers.add("AUTHORIZATION", $auth1);
$resp1 = $req1.GetResponse()
$reader1 = new-object System.IO.StreamReader($resp1.GetResponseStream())
[xml]$xmloutput1 = $reader1.ReadToEnd()
 
#here you find all edges:
foreach($edge1 in $xmloutput1.pagedEdgeList.edgePage.edgeSummary){
if($edge1.name -eq $edge_app_name){
        do {
        write-host "Waiting for edge to be in deployed state"
        sleep(10)
        }
        until ($edge1.state -eq 'deployed')
       }
    }
}

#Adding Static Routes
Function Adding_static_routes(){
 $Body = @"
<staticRouting>
<staticRoutes>
<route>
<vnic>1</vnic>
<network>${INTERNAL_network}</network>
<nextHop>${nexthop}</nextHop>
</route>
<route>
<vnic>1</vnic>
<network>${INTERNAL_network2}</network>
<nextHop>${nexthop}</nextHop>
</route>
</staticRoutes>
<defaultRoute>
<vnic>0</vnic>
<gatewayAddress>${gatewayaddr}</gatewayAddress>
</defaultRoute>
</staticRouting>
"@

Calling-Put -URL $url_static_routes -Body $Body

}

#Adding grouping Objects
Function Adding_grouping_objects1(){
    $Body = @"
 <ipset>
 <objectId /> 
 <type>
 <typeName /> 
 </type>
 <description>
 Virtual Center NAT INTERNAL IP
 </description>
 <name>Virtual Center Nat IP</name> 
 <revision>0</revision> 
 <objectTypeName /> 
 <value>${vcenter_INTERNAL_web_vip}</value> 
</ipset>
"@
    Calling-post -URL $url_grouping_objects -Body $Body
}

#Adding more grouping objects
Function Adding_grouping_objects2(){
    $Body = @"
 <ipset>
 <objectId /> 
 <type>
 <typeName /> 
 </type>
 <description>
 Nat INTERNAL Security Groups
 </description>
 <name>${DC_name} Terminal Servers</name> 
 <revision>0</revision> 
 <objectTypeName /> 
 <value>${DC_Terminal_Ipaddress}</value> 
</ipset>
"@
    Calling-post -URL $url_grouping_objects -Body $Body
}
 
#Getting the FW application ids which need to be used while configuring the fw
 Function get_fw_app_id(){
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
$auth = 'Basic ' + [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($vshieldDefaultUser+':'+$vShieldDefaultPass))

#GET all edges
$req = [System.Net.WebRequest]::Create($app_scope_url)
$req.Method ="GET"
$req.Headers.add("AUTHORIZATION", $auth);
$resp = $req.GetResponse()
$reader = new-object System.IO.StreamReader($resp.GetResponseStream())
[xml]$xmloutput = $reader.ReadToEnd()

#Parsing the XML and Grabbing the Application id's here

foreach($Appname in $xmloutput.list.application){
if($Appname.name -eq 'ICMP Echo'){
       $global:icmp_id = $Appname.objectId
       
       }
if($Appname.name -eq 'VMware-VC-Webaccess'){
       $global:vmware_vc_webaccess_id = $Appname.objectId
      # return $vmware_vc_webaccess_id
    }
if($Appname.name -eq 'HTTPS'){
    $global:https_id = $Appname.objectId
    #return $https_id
    }
    }
}

#Adding FW rules
Function Adding_Firewall_rules(){
    $Body = @"
 <?xml version="1.0"?>
<firewall>
<firewallRules>
<firewallRule>
<name>ICMP</name> 
<application> 
<applicationId>${icmp_id}</applicationId>
</application>
<action>accept</action>
<loggingEnabled>true</loggingEnabled>
</firewallRule>
<firewallRule>
<name>VMware VC WebAccess</name> 
<source> 
<groupingObjectId>${terminal_server_grouping_object_id}</groupingObjectId>
</source>
<destination>
<groupingObjectId>${vcenter_grouping_object_id}</groupingObjectId>
</destination>
<application> 
<applicationId>${vmware_vc_webaccess_id}</applicationId>
</application>
<action>accept</action>
<loggingEnabled>true</loggingEnabled>
</firewallRule>
<firewallRule>
<name>VI Client</name> 
<source> 
<groupingObjectId>${terminal_server_grouping_object_id}</groupingObjectId>
</source>
<destination>
<groupingObjectId>${vcenter_grouping_object_id}</groupingObjectId>
</destination>
<application> 
<applicationId>${https_id}</applicationId>
</application>
<action>accept</action>
<loggingEnabled>true</loggingEnabled>
</firewallRule>
</firewallRules>
</firewall>
"@
    Calling-Put -URL $Firewall_url -Body $Body
}

#Adding HA edge - function setup but not called due to inherent timeout issue vmware investigating
 Function Adding_HA_Edge(){
    $Body = @"
<highAvailability>
<vnic>2</vnic> 
<declareDeadTime>6</declareDeadTime>
<enabled>true</enabled>
</highAvailability>
"@
       Calling-Put -url $HA_url -Body $Body
}

#LB service enable function but not called due to inherent time out issue vmware investigating
 Function Enable_LB_Service(){
    $Body = @"
<loadBalancer>
<accelerationEnabled>true</accelerationEnabled>
<enabled>true</enabled>
</loadBalancer>
"@
       Calling-Put -url $LB_enable_url -Body $Body
}
 
##Adding LB pool functions begin here
Function Adding_Edge_LB_Pool1(){
  $Body_1 = @"
<?xml version="1.0" encoding="UTF-8"?> 
    <pool>
    <id>1</id>
    <name>VCENTER-INTERNAL-WEBSERVICES</name>
    <servicePort>
    <protocol>HTTP</protocol> 
    <algorithm>LEAST_CONN</algorithm>
    <port>80</port>
    <healthCheckPort>80</healthCheckPort>
    <healthCheck>
    <mode>HTTP</mode>
    <healthThreshold>2</healthThreshold>
    <unHealthThreshold>3</unHealthThreshold>
    <interval>5</interval>
    <uri>/</uri>
    <timeout>15</timeout>
     </healthCheck>
    </servicePort>
    <servicePort>
    <protocol>TCP</protocol> 
    <algorithm>LEAST_CONN</algorithm>
    <port>443</port>
    <healthCheckPort>443</healthCheckPort>
    <healthCheck>
    <mode>TCP</mode>
    <healthThreshold>2</healthThreshold>
    <unHealthThreshold>3</unHealthThreshold>
    <interval>5</interval>
    <uri>/</uri>
    <timeout>15</timeout>
    </healthCheck>
    </servicePort>
    <member>
    <ipAddress>${vcenter_exnet_ip}</ipAddress> 
    <weight>1</weight>
    <servicePort>
    <protocol>TCP</protocol>
    <port>443</port> 
    <healthCheckPort>443</healthCheckPort>
    </servicePort>
    </member>
</pool>
"@
   Calling-Post-LB -url1 $LB_pool_url -Body1 $Body_1
}

Function Adding_Edge_LB_Pool2(){
 $Body = @"
<?xml version="1.0" encoding="UTF-8"?> 
<pool>
<id>2</id>
<name>VCENTER-INTERNAL-WEBCLIENT</name>
<servicePort>
<protocol>HTTPS</protocol> 
<algorithm>LEAST_CONN</algorithm>
<port>9443</port>
<healthCheckPort>9443</healthCheckPort>
<healthCheck>
<mode>SSL</mode>
<healthThreshold>2</healthThreshold>
<unHealthThreshold>3</unHealthThreshold>
<interval>5</interval>
<uri>/</uri>
<timeout>15</timeout>
</healthCheck>
</servicePort>
<member>
<ipAddress>${vcenter_exnet_ip}</ipAddress> 
<weight>1</weight>
<servicePort>
<protocol>HTTPS</protocol>
<port>9443</port> 
<healthCheckPort>9443</healthCheckPort>
</servicePort>
</member>
</pool>
"@

    Calling-Post-LB -url1 $LB_pool_url -Body1 $Body
}


Function Adding_Edge_LB_Pool3(){
 $Body = @"
<?xml version="1.0" encoding="UTF-8"?> 
<pool>
<id>3</id>
<name>VCD-INTERNAL-CONSOLE</name>
<servicePort>
<protocol>TCP</protocol> 
<algorithm>LEAST_CONN</algorithm>
<port>443</port>
<healthCheckPort>443</healthCheckPort>
<healthCheck>
<mode>TCP</mode>
<healthThreshold>2</healthThreshold>
<unHealthThreshold>3</unHealthThreshold>
<interval>5</interval>
<uri>/</uri>
<timeout>15</timeout>
</healthCheck>
</servicePort>
<member>
<ipAddress>${vcd_exnet_console_ip1}</ipAddress> 
<weight>1</weight>
<servicePort>
<protocol>TCP</protocol>
<port>443</port> 
<healthCheckPort>443</healthCheckPort>
</servicePort>
</member>
<member>
<ipAddress>${vcd_exnet_console_ip2}</ipAddress> 
<weight>1</weight>
<servicePort>
<protocol>TCP</protocol>
<port>443</port> 
<healthCheckPort>443</healthCheckPort>
</servicePort>
</member>
</pool>
"@

    Calling-Post-LB -url1 $LB_pool_url -Body1 $Body
}

Function Adding_Edge_LB_Pool4(){
 $Body = @"
<?xml version="1.0" encoding="UTF-8"?> 
<pool>
<id>4</id>
<name>VCD-INTERNAL-WEB</name>
<servicePort>
<protocol>HTTPS</protocol> 
<algorithm>LEAST_CONN</algorithm>
<port>443</port>
<healthCheckPort>443</healthCheckPort>
<healthCheck>
<mode>SSL</mode>
<healthThreshold>2</healthThreshold>
<unHealthThreshold>3</unHealthThreshold>
<interval>5</interval>
<uri>/</uri>
<timeout>15</timeout>
</healthCheck>
</servicePort>
<member>
<ipAddress>${vcd_exnet_web_ip1}</ipAddress> 
<weight>1</weight>
<servicePort>
<protocol>HTTPS</protocol>
<port>443</port> 
<healthCheckPort>443</healthCheckPort>
</servicePort>
</member>
<member>
<ipAddress>${vcd_exnet_web_ip2}</ipAddress> 
<weight>1</weight>
<servicePort>
<protocol>HTTPS</protocol>
<port>443</port> 
<healthCheckPort>443</healthCheckPort>
</servicePort>
</member>
</pool>
"@

    Calling-Post-LB -url1 $LB_pool_url -Body1 $Body
}

Function Adding_Edge_LB_Pool5(){
 $Body = @"
<?xml version="1.0" encoding="UTF-8"?> 
<pool>
<id>5</id>
<name>VCD-EXNET-CONSOLE</name>
<servicePort>
<protocol>TCP</protocol> 
<algorithm>LEAST_CONN</algorithm>
<port>443</port>
<healthCheckPort>443</healthCheckPort>
<healthCheck>
<mode>TCP</mode>
<healthThreshold>2</healthThreshold>
<unHealthThreshold>3</unHealthThreshold>
<interval>5</interval>
<uri>/</uri>
<timeout>15</timeout>
</healthCheck>
</servicePort>
<member>
<ipAddress>${vcd_exnet_console_ip1}</ipAddress> 
<weight>1</weight>
<servicePort>
<protocol>TCP</protocol>
<port>443</port> 
<healthCheckPort>443</healthCheckPort>
</servicePort>
</member>
<member>
<ipAddress>${vcd_exnet_console_ip1}</ipAddress> 
<weight>1</weight>
<servicePort>
<protocol>TCP</protocol>
<port>443</port> 
<healthCheckPort>443</healthCheckPort>
</servicePort>
</member>
</pool>
"@

    Calling-Post-LB -url1 $LB_pool_url -Body1 $Body
}

Function Adding_Edge_LB_Pool6(){
 $Body = @"
<?xml version="1.0" encoding="UTF-8"?> 
<pool>
<id>6</id>
<name>VCD-EXNET-WEB</name>
<servicePort>
<protocol>HTTPS</protocol> 
<algorithm>LEAST_CONN</algorithm>
<port>443</port>
<healthCheckPort>443</healthCheckPort>
<healthCheck>
<mode>SSL</mode>
<healthThreshold>2</healthThreshold>
<unHealthThreshold>3</unHealthThreshold>
<interval>5</interval>
<uri>/</uri>
<timeout>15</timeout>
</healthCheck>
</servicePort>
<member>
<ipAddress>${vcd_exnet_web_ip1}</ipAddress> 
<weight>1</weight>
<servicePort>
<protocol>HTTPS</protocol>
<port>443</port> 
<healthCheckPort>443</healthCheckPort>
</servicePort>
</member>
<member>
<ipAddress>${vcd_exnet_web_ip2}</ipAddress> 
<weight>1</weight>
<servicePort>
<protocol>HTTPS</protocol>
<port>443</port> 
<healthCheckPort>443</healthCheckPort>
</servicePort>
</member>
</pool>
"@

    Calling-Post-LB -url1 $LB_pool_url -Body1 $Body
}

#Function to create virtual servers
Function Adding_Edge_VS0() {
 $Body = @"
<?xml version="1.0" encoding="UTF-8"?> 
<virtualServer> 
<name>VCENTER-INTERNAL-PORT902-VIP</name>
<description>VCENTER INTERNAL PORT902 VIP</description>
<ipAddress>${vcenter_INTERNAL_websvcs_Vip}</ipAddress>  
<applicationProfile> 
<protocol>TCP</protocol>
<port>902</port>
</applicationProfile>
<logging>
<enable>false</enable>
<logLevel>INFO</logLevel>
</logging>
<pool>
<id>1</id>
</pool>
</virtualServer>
"@
    Calling-Post-LB -url1 $LB_virtualserver_url -Body1 $Body
 }

Function Adding_Edge_VS1() {
 $Body = @"
<?xml version="1.0" encoding="UTF-8"?>
<virtualServer> 
<name>VCENTER-INTERNAL-WEBSERVICES-VIP</name>
<description>VCENTER INTERNAL WEBSVCS VIP</description>
<ipAddress>${vcenter_INTERNAL_websvcs_vip}</ipAddress> 
<applicationProfile> 
<protocol>HTTP</protocol>
<port>80</port>
<persistence> 
<method>COOKIE</method> 
<cookieName>JSESSIONID</cookieName>
<cookieMode>INSERT</cookieMode>
</persistence>
</applicationProfile>
<applicationProfile> 
<protocol>TCP</protocol>
<port>443</port>
</applicationProfile>
<logging>
<enable>false</enable>
<logLevel>INFO</logLevel>
</logging>
<pool>
<id>1</id>
</pool>
</virtualServer>
"@
    Calling-Post-LB -url1 $LB_virtualserver_url -Body1 $Body
 }

Function Adding_Edge_VS2() {
 $Body = @"
<?xml version="1.0" encoding="UTF-8"?>
<virtualServer> 
<name>VCENTER-INTERNAL-WEB-VIP</name>
<description>VCENTER INTERNAL WEB VIP</description>
<ipAddress>${vcenter_INTERNAL_web_vip}</ipAddress> 
<applicationProfile> 
<protocol>HTTPS</protocol>
<port>443</port>
</applicationProfile>
<logging>
<enable>false</enable>
<logLevel>INFO</logLevel>
</logging>
<pool>
<id>2</id>
</pool>
</virtualServer>
"@
    Calling-Post-LB -url1 $LB_virtualserver_url -Body1 $Body
 }

Function Adding_Edge_VS3() {
 $Body = @"
 <?xml version="1.0" encoding="UTF-8"?>
<virtualServer> 
<name>VCD-INTERNAL-CONSOLE-VIP</name>
<description>VCD INTERNAL Console VIP</description>
<ipAddress>${vcd_INTERNAL_console_vip}</ipAddress> 
<applicationProfile> 
<protocol>TCP</protocol>
<port>443</port>
</applicationProfile>
<logging>
<enable>false</enable>
<logLevel>INFO</logLevel>
</logging>
<pool>
<id>3</id>
</pool>
</virtualServer>
"@
    Calling-Post-LB -url1 $LB_virtualserver_url -Body1 $Body
 }

Function Adding_Edge_VS4() {
 $Body = @"
<?xml version="1.0" encoding="UTF-8"?>
<virtualServer> 
<name>VCD-INTERNAL-WEB-VIP</name>
<description>VCD INTERNAL WEB VIP</description>
<ipAddress>${vcd_INTERNAL_web_vip}</ipAddress> 
<applicationProfile> 
<protocol>HTTPS</protocol>
<port>443</port>
</applicationProfile>
<logging>
<enable>false</enable>
<logLevel>INFO</logLevel>
</logging>
<pool>
<id>4</id>
</pool>
</virtualServer>
"@
   Calling-Post-LB -url1 $LB_virtualserver_url -Body1 $Body
 }

Function Adding_Edge_VS5() {
 $Body = @"
 <?xml version="1.0" encoding="UTF-8"?>
<virtualServer> 
<name>VCD-EXNET-CONSOLE-VIP</name>
<description>VCD ExNet Console VIP</description>
<ipAddress>${vcd_exnet_console_vip}</ipAddress> 
<applicationProfile> 
<protocol>TCP</protocol>
<port>443</port>
</applicationProfile>
<logging>
<enable>false</enable>
<logLevel>INFO</logLevel>
</logging>
<pool>
<id>5</id>
</pool>
</virtualServer>
"@
    Calling-Post-LB -url1 $LB_virtualserver_url -Body1 $Body
 }

 Function Adding_Edge_VS6() {
 $Body = @"
<?xml version="1.0" encoding="UTF-8"?>
<virtualServer> 
<name>VCD-EXNET-WEB-VIP</name>
<description>VCD ExNet WEB VIP</description>
<ipAddress>${vcd_exnet_web_vip}</ipAddress> 
<applicationProfile> 
<protocol>HTTPS</protocol>
<port>443</port>
</applicationProfile>
<logging>
<enable>false</enable>
<logLevel>INFO</logLevel>
</logging>
<pool>
<id>6</id>
</pool>
</virtualServer>
"@
    Calling-Post-LB -url1 $LB_virtualserver_url -Body1 $Body
 }

 #I just declared a separate function for this post call
 Function Calling-Post-LB($url1,$Body1){
$auth1 = $vshieldDefaultUser + ':' + $vShieldDefaultPass
$Encoded1 = [System.Text.Encoding]::UTF8.GetBytes($auth1)
$EncodedPassword1 = [System.Convert]::ToBase64String($Encoded1)
$headers1 = @{"Authorization"="Basic $($EncodedPassword1)";}
try {Invoke-RestMethod -Headers $headers1 -Uri $url1 -Body $Body1 -Method Post -ContentType "Application/xml" } 
            catch { $_.Exception
                  write-host $url1 } 
}

#####Deploying the Edge#####
#First deploy the Edge Appliances
Deploy-Edge

#Set the Edge ID of the deployed appliance
Check-Edge-State
$edge_unique_id = Get-Edge-Id

#setting all the URL's here
$url_grouping_objects = "https://"+$vsmip+"/api/2.0/services/ipset/"+$edge_unique_id
$url_static_routes = "https://"+$vsmip+"/api/3.0/edges/"+$edge_unique_id+"/routing/config"
$app_scope_url = "https://"+$vsmip+"/api/2.0/services/application/scope/"+$edge_unique_id
$firewall_url = "https://"+$vsmip+"/api/3.0/edges/"+$edge_unique_id+"/firewall/config"
$HA_url = "https://"+$vsmip+"/api/3.0/edges/"+$edge_unique_id+"/highavailability/config"
$LB_pool_url = "https://"+$vsmip+"/api/3.0/edges/"+$edge_unique_id+"/loadbalancer/config/pools"
$LB_enable_url = "https://"+$vsmip+"/api/3.0/edges/"+$edge_unique_id+"/loadbalancer/config"
$LB_virtualserver_url = "https://"+$vsmip+"/api/3.0/edges/"+$edge_unique_id+"/loadbalancer/config/virtualservers"

#######Configuration of the Edge Starts here#######

Write-host "Creating LB Pools now.."
Adding_Edge_LB_Pool1 | Out-Null
Adding_Edge_LB_Pool2 | Out-Null
Adding_Edge_LB_Pool3 | Out-Null
Adding_Edge_LB_Pool4 | Out-Null
Adding_Edge_LB_Pool5 | Out-Null
Adding_Edge_LB_Pool6 | Out-Null

#Creating Edge LB Virtual Servers
Write-host "Adding LB Virtual Servers now.."
Adding_Edge_VS0
Adding_Edge_VS1
Adding_Edge_VS2
Adding_Edge_VS3
Adding_Edge_VS4
Adding_Edge_VS5
Adding_Edge_VS6


#Add static routes and default routes
Write-Host "Adding static routes now.."
Adding_static_routes


#Adding Object groups and getting the IDs which need to be passed over to create firewall rules
Write-host "Creating grouping objects now.."
$vcenter_grouping_object_id = Adding_grouping_objects1
$terminal_server_grouping_object_id = Adding_grouping_objects2

#Getting Application ids which need to be passed over to create firewall rules
get_fw_app_id

#Creating the Firewall rules 
Write-host "Creating FW rules now.."
Adding_Firewall_rules


