VMware-vShield-5.5.2-Edge-Automation
==============================

vShield 5.5.2 Edge Deployment and Configuration Automation Using PowerCli + Restful API.

++++++
Notice == Script tested on ESXi 5.5 running vCenter 5.5 Update 2. No guarantees. Ensure you run it on test environment before executing in production. Owner assumes ZERO liability.
++++++

Introduction
============

The Script allows you to deploy vShield Edge Appliance to a vCenter and also configures. The script configures the following for the edge appliance,

1. Deployes it with three uplinks for External,internal and heartbeat networks
2. Configures firewall rules
3. Configures object-groups
4. Configures static routes
5. Configures LB rules

It uses Powershell and vShield 5.5.2 Rest API to deploy and configure the vShield Edge Appliance.

The edge was deployed for traffic to balance for a vcloud director use case. You will need to modify the config and comment the script out if you do not use vcloud director.

Prerequisites
=============

1. Powershell version 4.0
2. PowerCli version 5.8 Release 1
3. Network able to access vCenter and vShield IP's. 

Parts
=====
a. edge-config.xml
b. Edge-deploy.ps1

Execution Method
================

Follow the below steps to properly execute the file.

1. Ensure edge-config.xml and Edge-deploy.ps1 are in the same folder.
2. Populate edge-config.xml with all the info as per your vcenter and vshield info. This allows you to configure your inputs before you execute the script.
3. Execute the script once edge-config.xml is configured.

Contents Config.xml
===================
```xml
<?xml version="1.0"?>
<MasterConfig>

<vcenterconfig>
<vcenterfqdn>FQDN OF VCENTER</vcenterfqdn>
<vcenteruser>VCENTER USER</vcenteruser>
<vcenterpassword>PASSWORD OF VCENTER USER</vcenterpassword>
<Edge_cluster>CLUSTER NAME</Edge_cluster>
<Edge_datacenter>DATACENTER NAME</Edge_datacenter>
<InternalDVportgroup_name>INTERNAL NETWORK</InternalDVportgroup_name>
<ExternalDVportgroup_name>EXTERNAL NETWORK</ExternalDVportgroup_name>
<HeartbeatDVportgroup_name>HEARTBEAT NETWORK</HeartbeatDVportgroup_name>
<Edge_datastore>DATASTORE</Edge_datastore>
</vcenterconfig>

<Edgeconfig>
<Edge_app_name>EDGE APP NAME</Edge_app_name>
<Edge_app_description>This is a testing edge appliance</Edge_app_description>
<Edge_password>COMPLEX PASSWORD</Edge_password>
</Edgeconfig>

<EdgeIPConfig>
<Edge_exnet_ip>EDGE EXTERNAL IP</Edge_exnet_ip>
<VCD_vmnet_web_vip>INTERNAL VCD WEB NETWORK IP</VCD_vmnet_web_vip>
<VCD_vmnet_console_vip>INTERNAL VCD CONSOLE IP</VCD_vmnet_console_vip>
<vcenter_vmnet_web_vip>INTERNAL VCENTER WEB VIP</vcenter_vmnet_web_vip>
<vcenter_vmnet_websvcs_vip>INTERNAL VCENTER WEBSVCS VIP</vcenter_vmnet_websvcs_vip>
<vcd_exnet_console_vip>VCD EXNET CONSOLE VIP</vcd_exnet_console_vip>
<vcd_exnet_web_vip>VCD EXNET WEB VIP</vcd_exnet_web_vip>
<vcenter_exnet_ip>VCENTER EXNET IP</vcenter_exnet_ip>
<vcd_exnet_console_ip1>VCD CONSOLE EXNET IP CELL 1</vcd_exnet_console_ip1>
<vcd_exnet_console_ip2>VCD CONSOLE EXNET IP CELL 2</vcd_exnet_console_ip2>
<vcd_exnet_web_ip1>VCD HTTP EXNET WEB IP CELL 1</vcd_exnet_web_ip1>
<vcd_exnet_web_ip2>VCD HTTP EXNET WEB IP CELL 2</vcd_exnet_web_ip2>
<DC_terminal_ip>JUMP BOX IP</DC_terminal_ip>
<DC_Name>DATACENTER NAME</DC_Name>
</EdgeIPConfig>

<routes>
<Vmnet_network>INTERNAL SUBNET</Vmnet_network>
<Vmnet_network2>INTERNAL SUBNET</Vmnet_network2>
<gatewayaddr>DEFAULT GATEWAY</gatewayaddr>
<nexthop>NEXTHOP IP</nexthop>
</routes>

<vShieldAppConfig>
<vshield_ip>VSHIELD APPLIANCE IP</vshield_ip>
<vshielduser>admin</vshielduser>
<vshieldpass>default</vshieldpass>
</vShieldAppConfig>

</MasterConfig>
```
Known Issues
============

1. Edge HA times out and has been disabled in the code. The HA function needs to be called separately than the Edge deployment code and is currently under investigation with VMware for a possible issue.

2. Enabling the Edge LB service times out and has been disabled in the code. The service function needs to be called separately than the Edge deployment code and is currently under investigation with VMware for a possible issue.

3. Ensure that the load balancer pools and virtual servers are first created before any other services are configured. This is a work flow api issue possibly and VMware is investigating.

KB
============

1. There are 400 bad payload errors when edge deploy starts - Ensure your edge password is complex


