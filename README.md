# melcloud
Vera Device to manage a Melcloud connexion to Mitsubishi AC system
## Installation
### Download files
Download the 9 files in Vera Ui:

*Apps* > *Develop apps* > *Luup files*
### Create the controler
*Apps* > *Develop apps* > *Create device*  
*Description*: Melcloud Controler  
*Upnp Device Filename*: D\_Melcloud1.xml  
*Upnp Implementation  Filename* : I\_Melcloud1.xml

A new Device will appears on the panel
###Configure the controler
*Advanced* > *Variables*   
1. MelcloudUser : your email address used to connect to Melcloud 
2. melCloudPwd : your password  
Reload the engine  
*The icon should be green meaning that the pluggin is connected to melcloud*  
Clic on *'Discover the devices'*    
 The plugin will scan all the melcloud trees and will create as many devices as devives present on the melcloud system.
###Use  
+ Fan: a slier from 0 to 6 allows you to change the fan speed. 0 is *auto*
+ Temperature : Increase or decrease the temperature of the device  
+ Room temperature is displayed  
+ Mode : 4 button to change the operating mode of the AC
  *Notice that the commands are send immediately to the system* 
