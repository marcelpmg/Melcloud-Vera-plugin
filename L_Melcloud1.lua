module("L_Melcloud1", package.seeall)
-------
----------- Lua pluggin management Mitsubishi Melcloud
------
local ssl = require 'ssl'
local https = require 'ssl.https'
local socket = require 'socket'
local ltn12 = require 'ltn12'
json = require("dkjson")
local ML_DEVICE = "urn:schemas-didierco-vera:device:MelcloudDev:1"
local ML_SID    = "urn:didierco-vera:serviceId:Melcloud1"
local SWITCHPWR_SID = "urn:upnp-org:serviceId:SwitchPower1"
local TEMP_SID  = "urn:upnp-org:serviceId:TemperatureSetpoint1"
local HA_SID  = "urn:upnp-org:serviceId:HVAC_UserOperatingMode1"
local TMPS_SID  = "urn:upnp-org:serviceId:TemperatureSensor1"
local FAN_SID = "urn:upnp-org:serviceId:HVAC_FanOperatingMode1"
local myDevice
local DEBUG_MODE = false
local BASE_URL = "app.melcloud.com"
local MODES = {"HeatOn", "DryOn","CoolOn","","","","VentOn", "AutoChangeOver"}
local accToken
local child_devices = luup.chdev.start(lul_device) -- used for chidren creation
local childrenParam = {} -- storage of the device Info from melcloud


------------------------------
-- Modification de la temperature de consigne
-- déclenchée par une action dans le fichier xml d'implementation
-- (I_Melcloud1.xml)
------------------------------
function SetPoint(lul_device, lul_settings)
   curSetting = luup.variable_get(TEMP_SID, "CurrentSetpoint", lul_device)
   luup.log("Mel cloud #" .. lul_device .. " set current point :" .. curSetting
   .. "new:" ..lul_settings.NewCurrentSetpoint)

   if (childrenParam[lul_device] == nil) then
      luup.log("Mel cloud #" .. lul_device .. " pas de données sauvegardées!!",1)
   else
      luup.log("Mel cloud #" .. lul_device .. " données réelle:"..childrenParam[lul_device].SetTemperature)
      childrenParam[lul_device].SetTemperature = lul_settings.NewCurrentSetpoint     
	  childrenParam[lul_device].EffectiveFlags = 4
      childrenParam[lul_device].HasPendingCommand = true
      rc = modifParam(childrenParam[lul_device]) -- envoi de la modification vers Melcloud
      if (rc ~= nil) then
         luup.variable_set(TEMP_SID, "CurrentSetpoint", lul_settings.NewCurrentSetpoint, lul_device)
		 else
         luup.log("Mel cloud #" .. lul_device .. " Modif impossible pour"..childrenParam[lul_device].SetTemperature)
      end
   end
   return 1
end
------------------------------
-- Modification de la vitesse de ventilation
-- déclenchée par une action dans le fichier xml d'implementation
-- (I_Melcloud1.xml)
------------------------------
function SetFan(lul_device, lul_settings)

   curFanSetting = luup.variable_get(FAN_SID, "FanMode",  lul_device)
   luup.log("Mel cloud #" .. lul_device .. " set fan Speed :" .. curFanSetting
   .. "new:" ..lul_settings.NewFanMode)

   if (childrenParam[lul_device] == nil) then
      luup.log("Mel cloud #" .. lul_device .. " pas de données sauvegardées!!",1)
   else
      luup.log("Mel cloud #" .. lul_device .. " données réelle:"..childrenParam[lul_device].SetFanSpeed)
      childrenParam[lul_device].SetFanSpeed = lul_settings.NewFanMode     
	  childrenParam[lul_device].EffectiveFlags = 8 -- 8= modif fanSpeed
      childrenParam[lul_device].HasPendingCommand = true
      rc = modifParam(childrenParam[lul_device]) -- envoi de la modification vers Melcloud
      if (rc ~= nil) then
			luup.variable_set(FAN_SID, "FanMode", lul_settings.NewFanMode, lul_device)
			luup.variable_set(FAN_SID, "currentFan", lul_settings.NewFanMode, lul_device)
		 else
         luup.log("Mel cloud #" .. lul_device .. " Modif impossible pour"..childrenParam[lul_device].FanMode)
      end
   end
   return 1
end

------------------------------
-- Modification du mode fonctionnement
-- déclenchée par une action dans le fichier xml d'implementation
-- (I_Melcloud1.xml)
------------------------------

function SetModeTarget(lul_device, lul_settings)
   curSetting = luup.variable_get(HA_SID, "ModeTarget", lul_device)
   luup.log("Mel cloud #" .. lul_device .. " set modeTarget de :" .. curSetting
   .. " new:" ..lul_settings.NewModeTarget)
   if (childrenParam[lul_device] == nil) then
      luup.log("Mel cloud #" .. lul_device .. " pas de données sauvegardées!!",1)
   else

      if (lul_settings.NewModeTarget == "Off") then

         childrenParam[lul_device].Power = false -- on vient d'éteindre
         childrenParam[lul_device].EffectiveFlags = 1 -- = power
      else

         childrenParam[lul_device].Power = true -- on allume
         childrenParam[lul_device].EffectiveFlags = 3 --= power + op mode
         j = decodeMode(lul_settings.NewModeTarget)
         if (j) then
            childrenParam[lul_device].OperationMode = j
         else
            luup.log("Mel cloud #" .. lul_device .. " op. mode inconnu:"..
              lul_settings.NewModeTarget)
         end
      end

      rc = modifParam(childrenParam[lul_device]) -- envoi de la modification vers Melcloud
      if (rc ~= nil) then
         luup.variable_set(HA_SID, "ModeTarget", 
           lul_settings.NewModeTarget, lul_device)
         luup.variable_set(HA_SID, "ModeStatus", 
           lul_settings.NewModeTarget, lul_device)
      else
         luup.log("Mel cloud #" .. lul_device .. " Modif impossible")
      end
   end
   return 1
end

-- Decode les op mode de string vers numeric utilisé par Melcloud
function decodeMode(strMode)
   print ("lng mode:"..#MODES)
   for i = 1,#MODES do
      if(strMode == MODES[i]) then
         return i
      end
      print(MODES[i])
   end
   return nil
end


------------------------------
--
-- Envoi de la modification d'une variable
-- vers le serveur Melcloud
--
------------------------------

function modifParam(devParams)


   local reqbody = json.encode (devParams, { indent = false })
   local url = "/Mitsubishi.Wifi.Client/Device/SetAta"

   zobi, reponsePost =  postHttps(url,reqbody,accToken,2)
   return reponsePost
end
------------------------------
-- Init Pluggin du Controler
------------------------------
function mlStartup(lul_device)
--	require('mobdebug').start('192.168.1.95')
   luup.log("Melcloud #" .. lul_device .. " Startup  " )
  -- require('mobdebug').done()
   runOnce(lul_device)
   luup.variable_set(ML_SID, "StConnexion", "0", lul_device) -- l'icone est grisé tant qu'on est pas connecté

   myDevice = lul_device

   accToken = MelcloudPlugin.login()
   if (accToken ~= nil) then
      luup.log("Melcloud #" .. lul_device .." token :".. accToken.. " Fin du Startup  " )
      -- changement de l'icone en vert
      luup.variable_set(ML_SID, "StConnexion", "1", lul_device)

      -- initialisation of the children we have created
      initChildren()

      -- stockage du token?
      return 0
   end
   luup.log("Melcloud #" .. lul_device .." fin du statup",2)
   -- changement de couleur de l'icone en rouge
   luup.variable_set(ML_SID, "StConnexion", "2", lul_device)
   return 1


end
------------------------------
-- Init Pluggin Device
------------------------------
function mlDevStartup(lul_device,melcloudID)

end
------------------------------
-- Initialisation first run of the Startup
------------------------------
function runOnce(lul_device)


   Version = luup.variable_get(ML_SID, "Version", lul_device)
   if (Version == nil) then
      luup.log("Melcloud #" .. lul_device .. " Init des variables " )
      -- Init variables Connexion parms
      luup.variable_set(ML_SID, "MelcloudUser", "", lul_device)
      luup.variable_set(ML_SID, "melCloudPwd", "", lul_device)
      luup.variable_set(ML_SID, "melCloudToken", "", lul_device)
      luup.variable_set(ML_SID, "Version", "1", lul_device)
      luup.variable_set(ML_SID, "StConnexion", "0", lul_device)
      luup.variable_set(ML_SID, "DecDevices", "No", lul_device)


      luup.log("Melcloud #" .. lul_device .. " Fin Init des variables ")


   end
end
---------------------------------
---- Login to Melcloud
---- Password and Username are stored in the device variables
---- "MelcloudUser" and "melCloudPwd"
---------------------------------
function login()

   local s_username = luup.variable_get(ML_SID, "MelcloudUser", myDevice)
   local s_password = luup.variable_get(ML_SID, "melCloudPwd", myDevice)
   local url = "/Mitsubishi.Wifi.Client/Login/ClientLogin"
   reqbody=  "&AppVersion=1.20.5.0&Language=7&CaptchaResponse=&Persist=false"
   .. "&Email=" .. s_username .. "&Password=" .. s_password
   rc, reponsePost =  postHttps(url,reqbody,"",1)
   if (rc) then -- return code OK
      if (reponsePost.ErrorId == 1) then -- mauvais login
         luup.log("Melcloud #" .. myDevice .. " Credential error, user :".. s_username .."pwd:".. s_password,2)
         return nil
      else

         return reponsePost.LoginData.ContextKey
      end
   else

      return nil
   end
end

---------------------------------
---- The user has clicked
---- on the botton 'discover the device
---- We gonna scan the data in the melcloud database
---- in order to find out the differents devices presents
---------------------------------
function decouverteDevices(lul_device,lul_settings)
   curSetting = luup.variable_get(ML_SID, "DecDevices", lul_device)
   luup.log("Mel cloud #" .. lul_device .. " set decDevices "
   .. " new:" ..lul_settings.NewDecDevices)
   luup.variable_set(ML_SID, "DecDevices", lul_settings.NewDecDevices, lul_device)
   luup.log("Melcloud #" .. lul_device .. " Discovering devices...")
   ct = luup.variable_get(ML_SID, "StConnexion", lul_device)
   if( ct == "1")then
      getDevices(lul_device,lul_settings)
   else
      luup.log("Melcloud #" .. log_level .. "  Impossible discovering, no connexion!",2)
   end
end
---------------------------
--------
--------Device list analysis
--------
---------------------------
function getDevices(lul_device,lul_settings)
   rc, reponsePost = getHttps("/Mitsubishi.Wifi.Client/User/ListDevices",accToken)
   if (rc == false) then --erreur
      luup.log("Melcloud #" .. myDevice .. " No access to the devices list  ",1)
      return nil
   end
   --boucle sur les building
   for i = 1, #reponsePost do
      building = reponsePost[i]
      luup.log("Melcloud #" .. myDevice .. "Building :"..building.Name)
      buildingId = building.ID
      struct =  building.Structure.Floors
      --boucle sur les étages
      for j = 1, #struct do
         floor = struct[j]
         --On peut avoir des device au niveau de l'étage
         devs = floor.Devices
         for l = 1, #devs do
            device = devs[l]
            luup.log("Melcloud #" .. myDevice .. "Appareil :"..device.DeviceName)

            --
            -- Code de création des children dans Vera
            --....
            --
         end
         luup.log("Melcloud #" .. myDevice .. "Etage :"..floor.Name)
         --boucle sur les pieces
         rooms = floor.Areas
         for k = 1, #rooms do
            room = rooms[k]
            luup.log("Melcloud #" .. myDevice .. "Pièce :"..room.Name)
            --On peut avoir des device au niveau de la pièce
            devs = room.Devices
            for l = 1, #devs do
               device = devs[l]
               luup.log("Melcloud #" .. myDevice .. "Appareil :"..device.DeviceName)

               --
               -- Code de création des children dans Vera
               --l'altId est egal à ML+ id du device +Bld et l'ID du building
               --
               luup.chdev.append(lul_device, child_devices, "ML" .. tostring(device.DeviceID)..";Bld"..buildingId, device.DeviceName, ML_DEVICE, "D_MelcloudDev1.xml", "", "", false)


               --
            end
         end
      end
   end



   -- sync des enfants créés
   luup.chdev.sync(lul_device, child_devices)

end

---------------------------------
---- Children init
----
---------------------------------

function initChildren()

   for k, v in pairs(luup.devices) do

      if (v.id:find("^ML(.+)$")) then
         -- It is one of the device
         luup.log("Found one Melcloud device # :" ..k.." ".. v.id)
         myChildren[k] = v.id
      end

      --  end
   end

   initVariables()

end

---------------------------------
---- Variable of Children init
----
---------------------------------
initVariables = function ()

for k2, v2 in pairs(myChildren) do
   luup.log( k2 .. "=" .. tostring(v2))
   getInfosfromADevice(v2,k2)
end

-- refresh variable every 10'
rc = luup.call_timer("initVariables",1, 600)
luup.log("Melcloud #"  .. " RC call_delay:" .. rc)
end


---------------------------------
---- https request
---- POST method
---------------------------------
function postHttps(sUrl,reqBody,contextKey,content)
local respBody = {}
if (content == 1) then
   ct ="application/x-www-form-urlencoded; charset=utf-8"
else
   ct = "application/json; charset=utf-8"
end

urlx ="https://"..BASE_URL..sUrl
local result, status, respheaders, libstatus = https.request {
   method = "POST",
   protocol = "tlsv1_2",
   url = "https://"..BASE_URL..sUrl,
   source = ltn12.source.string(reqBody),
   sink = ltn12.sink.table(respBody),
   mode = "client",
   verify = "none",
   options = "all",
   headers = {
      ["Host"] = BASE_URL,
      ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:85.0) Gecko/20100101 Firefox/85.0",
      ["Accept"] = "application/json, text/javascript, */*; q=0.01",
      ["Accept-Language"] = "fr,fr-FR;q=0.8,en-US;q=0.5,en;q=0.3",
      ["Accept-Encoding"] = "gzip, deflate, br",
      ["X-Requested-With"] = "XMLHttpRequest",
      ["Origin"] = "https://app.melcloud.com",
      ["DNT"] = "1",
      ["Connection"] = "keep-alive",
      ["Referer"] = "https://app.melcloud.com/",
      ["Cookie"] = "policyaccepted=true",
      ["Pragma"] = "no-cache",
      ["Cache-Control"] = "no-cache",
      ["TE"] = "Trailers",
      ["Content-Type"] = ct,
      ["content-length"] = string.len(reqBody),
      ["X-MitsContextKey"] = contextKey
   }
}
status = tonumber(status)
if status >= 200 and status < 400 then

   luup.log("Melcloud #" .. myDevice .. " https OK:" .. status)

   return true, json.decode(table.concat(respBody))
else
   luup.log("Melcloud #" .. myDevice .. " Erreur http:" .. status,1)
   if (status == 401) then -- token invalid we relog
      accToken = login()
   end

   return false, nil
end


return
end

---------------------------------
---- https request
---- GET method
---------------------------------
function getHttps(sUrl,contextKey)
-- first time we run the http get,
-- without been connected
if (accToken == nil) then
   accToken = login()
   contextKey =accToken
end
local respBody = {}
urlx ="https://"..BASE_URL..sUrl
local result, status, respheaders, respstatus = https.request {
   method = "GET",
   protocol = "tlsv1_2",
   url = "https://"..BASE_URL..sUrl,

   sink = ltn12.sink.table(respBody),
   mode = "client",
   verify = "none",
   options = "all",
   headers = {
      ["Host"] = BASE_URL,

      ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:85.0) Gecko/20100101 Firefox/85.0",
      ["Accept"] = "application/json, text/javascript, */*; q=0.01",
      ["Accept-Language"] = "fr,fr-FR;q=0.8,en-US;q=0.5,en;q=0.3",
      ["Accept-Encoding"] = "gzip, deflate, br",

      ["X-MitsContextKey"] = contextKey,
      ["DNT"] = "1",
      ["Connection"] = "keep-alive"
   }
}
status = tonumber(status)

if status >= 200 and status < 400 then

   luup.log("Melcloud #" .. myDevice .. " https OK:" .. status)

   return true, json.decode(table.concat(respBody))
else
   luup.log("Melcloud #" .. myDevice .. " Erreur http:" .. status,1)
   if (status == 401) then -- token invalid we relog
      accToken = login()
   end

   return false, nil
end


end


--------------------
-- Retreive info of one device
--
------------------------
function getInfosfromADevice(melcloudID,veraDev)
--Codification des modes de Melcloud


local dID, bID = melcloudID:match("([^,]+);Bld([^,]+)",3)
luup.log("Melcloud #" .. veraDev .. " Refreshing datas from".. dID..", building #".. bID)
rc, reponsePost = getHttps("/Mitsubishi.Wifi.Client/Device/Get?id="
..dID.."&buildingID="..bID,accToken)
if (rc == false) then --erreur
   luup.log("Melcloud #" .. veraDev .. " No access to the devices #".. dID..", building #".. bID,1)
   luup.variable_set(ML_SID, "StConnexion", "2", veraDev)
   return nil
end
-- on sauvegarde les info du device pour l'utiliser
-- en cas de modification par l'utilisateur
-- on a plusieurs device donc on a une sauvegarde par device
childrenParam[veraDev] = reponsePost
-- mise a jour de la temperature de la pièce
luup.variable_set(TMPS_SID, "CurrentTemperature", reponsePost.RoomTemperature, veraDev)
-- mise a jour du mode de ventilation
luup.variable_set(FAN_SID, "FanMode", reponsePost.SetFanSpeed, veraDev)

-- cette variable va reformer la temperature courante
-- avec une jolie couleur et une jolie police
luup.variable_set(TMPS_SID, "FormatedCurrentTemp", "<div><style type=\"text/css\">.temp{font-family:arial;font-size:40px;color:#ff9900;}</style><div class=\"temp\">"..reponsePost.RoomTemperature.."°</div></div>", veraDev)

--  Temperature de consigne
luup.variable_set(TEMP_SID, "CurrentSetpoint", reponsePost.SetTemperature, veraDev)
-- if the split if power off ,
-- we set the mode to off
if(reponsePost.Power == false) then
   oppMode = "Off"
else
   oppMode = MODES[reponsePost.OperationMode]
end
luup.variable_set(HA_SID, "ModeTarget", oppMode, veraDev)
luup.variable_set(HA_SID, "ModeStatus", oppMode, veraDev)

Version = luup.variable_get(ML_SID, "Version", veraDev)
luup.variable_set(ML_SID, "StConnexion", "1", veraDev)
-- si la variable version existe on ne fait rien les variables on deja été créées
if (Version == nil) then
   luup.log("Melcloud #" .. veraDev .. " Device init  " )
   -- On surveille la variable ModeTarget qui contient le mode modifié
   --luup.variable_watch('watchHandler', HA_SID, "ModeTarget", lul_device)
   -- variable générales pour SwitchPower
   luup.variable_set(SWITCHPWR_SID, "Target", "", veraDev)
   luup.variable_set(SWITCHPWR_SID, "Status", "", veraDev)


   luup.variable_set(ML_SID, "Version", "1", veraDev)
   luup.log("Melcloud #" .. veraDev .. " Fin Device init :" .. luup.devices[veraDev].id)


end

end