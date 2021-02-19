module("L_Melcloud1", package.seeall)
-------
----------- Lua pluggin management Mitsubishi Melcloud
------

local ML_SID    = "urn:didierco-vera:serviceId:Melcloud"
local SWITCHPWR_SID = "urn:upnp-org:serviceId:SwitchPower1"
local TEMP_SID  = "urn:upnp-org:serviceId:TemperatureSetpoint1"
local HA_SID  = "urn:upnp-org:serviceId:HVAC_UserOperatingMode1"
local DEBUG_MODE = false
---------------------


function SetPoint(lul_device, lul_settings)
   curSetting = luup.variable_get(TEMP_SID, "CurrentSetpoint", lul_device)
   luup.log("Mel cloud #" .. lul_device .. " set current point :" .. curSetting
   			.. "new:" ..lul_settings.NewCurrentSetpoint)
   luup.variable_set(TEMP_SID, "CurrentSetpoint", lul_settings.NewCurrentSetpoint, lul_device)
   return 1
end
---------------------
function SetModeTarget(lul_device, lul_settings)
   curSetting = luup.variable_get(HA_SID, "ModeTarget", lul_device)
   luup.log("Mel cloud #" .. lul_device .. " set modeTarget de :" .. curSetting
   			.. " new:" ..lul_settings.NewModeTarget)
   luup.variable_set(HA_SID, "ModeTarget", lul_settings.NewModeTarget, lul_device)
 
   return 1
end
--[[
function watchHandler(numDev, service, variable, oldVal, newVal)
	luup.log("Melcloud # " .. numDev .. " Handler sur ".. variable ..
			", ancienne valeur:".. oldVal .. "Nouvelle :".. newVal )
-- Envoie la commande vers Melcloud

--- Met à jour ModeStatus
	luup.variable_set(HA_SID, "ModeStatus", newVal, numDev)
--]]

------------------------------
-- Gestion de la modification d'une variable
-- déclenchée par un luup.variable_watch dans le 
-- Startup
------------------------------
function watchHandler(numDev, service, variable, oldVal, newVal)
	luup.log("Melcloud # " .. numDev .. " Handler sur ".. variable ..
			", ancienne valeur:".. oldVal .. "Nouvelle :".. newVal )
-- Envoie la commande vers Melcloud

--- Met à jour ModeStatus
	luup.variable_set(HA_SID, "ModeStatus", newVal, numDev)
end

------------------------------
-- Init Pluggin
------------------------------
function mlStartup(lul_device)
   luup.log("Melcloud #" .. lul_device .. " Startup  " )
	runOnce(lul_device) 
	-- On surveille la variable ModeTarget qui contient le mode modifié
	luup.variable_watch('watchHandler', HA_SID, "ModeTarget", lul_device)
    luup.log("Melcloud #" .. lul_device .. " Fin du Startup  " )
	return 0
end
------------------------------
-- Initialisation first run of the Startup 
------------------------------
function runOnce(lul_device)
	
  
	Version = luup.variable_get(ML_SID, "Version", lul_device)
	if (Version == nil) then
	 luup.log("Melcloud #" .. lul_device .. " Creation device :" .. luup.devices[lul_device].id)
   -- Init variables Connexion parms
   luup.variable_set(ML_SID, "MelcloudUser", "", lul_device)
   luup.variable_set(ML_SID, "melCloudPwd", "", lul_device)
   luup.variable_set(ML_SID, "melCloudToken", "", lul_device)
   luup.variable_set(ML_SID, "Version", "1", lul_device)
   -- variable générales pour SwitchPower
   luup.variable_set(SWITCHPWR_SID, "Target", "", lul_device)
   luup.variable_set(SWITCHPWR_SID, "Status", "", lul_device)
   -- variable générales pour TemperatureSetpoint1
   luup.variable_set(TEMP_SID, "CurrentSetpoint", "", lul_device)
   luup.log("Melcloud #" .. lul_device .. " Fin Creation device :" .. luup.devices[lul_device].id)
      -- variable générales pour HA user mode
   luup.variable_set(HA_SID, "ModeTarget", "", lul_device)
   luup.variable_set(HA_SID, "ModeStatus", "", lul_device)

	end
end
