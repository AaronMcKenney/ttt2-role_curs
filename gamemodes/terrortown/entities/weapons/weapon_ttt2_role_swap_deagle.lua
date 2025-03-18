--Shamelessly taken from the Sidekick Deagle

SWEP.Base = "weapon_tttbase"

SWEP.Spawnable = true
SWEP.AutoSpawnable = false
SWEP.AdminSpawnable = true

SWEP.HoldType = "revolver"

SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false

if SERVER then
	AddCSLuaFile()
	
	resource.AddFile("materials/vgui/ttt/icon_role_swap_deagle.vmt")
	
	util.AddNetworkString("ttt_role_swap_deagle_refilled")
	util.AddNetworkString("ttt_role_swap_deagle_miss")
end

if CLIENT then
	SWEP.PrintName = "RoleSwap Deagle"
	SWEP.Author = "BlackMagicFine"
	
	SWEP.ViewModelFOV = 54
	SWEP.ViewModelFlip = false
	
	SWEP.Category = "Deagle"
	SWEP.Icon = "vgui/ttt/icon_role_swap_deagle.vtf"
	SWEP.EquipMenuData = {
		type = "item_weapon",
		name = "DEAGLE_NAME_" .. CURSED.name,
		desc = "DEAGLE_DESC_" .. CURSED.name
	}
end

--Gun stats
SWEP.Primary.Delay = 1
SWEP.Primary.Recoil = 6
SWEP.Primary.Automatic = false
SWEP.Primary.NumShots = 1
SWEP.Primary.Damage = 0
SWEP.Primary.Cone = 0.00001
SWEP.Primary.Ammo = ""
SWEP.Primary.ClipSize = 1
SWEP.Primary.ClipMax = 1
SWEP.Primary.DefaultClip = 1

--Misc.
SWEP.InLoadoutFor = nil
SWEP.AllowDrop = false
SWEP.IsSilent = false
SWEP.NoSights = false
SWEP.UseHands = true
SWEP.Kind = WEAPON_EXTRA
SWEP.CanBuy = {}
SWEP.LimitedStock = true
SWEP.globalLimited = true
SWEP.NoRandom = true
SWEP.notBuyable = true

--Model
SWEP.ViewModel = "models/weapons/cstrike/c_pist_deagle.mdl"
SWEP.WorldModel = "models/weapons/w_pist_deagle.mdl"
SWEP.Weight = 5
SWEP.Primary.Sound = Sound("Weapon_Deagle.Single")

--Iron sights
SWEP.IronSightsPos = Vector(-6.361, -3.701, 2.15)
SWEP.IronSightsAng = Vector(0, 0, 0)

local function RoleSwapDeagleRefilled(wep)
	if not IsValid(wep) then
		return
	end
	
	local text = LANG.GetTranslation("RECHARGED_" .. CURSED.name)
	MSTACK:AddMessage(text)
	
	STATUS:RemoveStatus("ttt2_role_swap_deagle_reloading")
	net.Start("ttt_role_swap_deagle_refilled")
	net.WriteEntity(wep)
	net.SendToServer()
end

local function RoleSwapDeagleCallback(attacker, tr, dmg)
	if CLIENT then return end
	
	local target = tr.Entity
	
	--Invalid shot return
	if not GetRoundState() == ROUND_ACTIVE or not IsValid(attacker) or not attacker:IsPlayer() or not attacker:IsTerror() then
		return
	end
	
	if not IsValid(target) or not target:IsPlayer() or not target:IsTerror() or not 
	CURS_DATA.AttemptSwap(attacker, target, 0) then
		--Miss or failed: start cooldown timer and return
		if GetConVar("ttt2_role_swap_deagle_refill_time"):GetInt() > 0 then
			net.Start("ttt_role_swap_deagle_miss")
			net.Send(attacker)
		end
		
		return
	end
	
	return true
end

function SWEP:OnDrop()
	self:Remove()
end

function SWEP:ShootBullet(dmg, recoil, numbul, cone)
	cone = cone or 0.01
	
	local bullet = {}
	bullet.Num = 1
	bullet.Src = self:GetOwner():GetShootPos()
	bullet.Dir = self:GetOwner():GetAimVector()
	bullet.Spread = Vector(cone, cone, 0)
	bullet.Tracer = 0
	bullet.TracerName = self.Tracer or "Tracer"
	bullet.Force = 10
	bullet.Damage = 0
	bullet.Callback = RoleSwapDeagleCallback
	
	self:GetOwner():FireBullets(bullet)
	self.BaseClass.ShootBullet(self, dmg, recoil, numbul, cone)
end

function SWEP:OnRemove()
	if CLIENT then
		STATUS:RemoveStatus("ttt2_role_swap_deagle_reloading")
		
		timer.Stop("ttt2_role_swap_deagle_refill_timer")
	end
end

if CLIENT then
	hook.Add("Initialize", "InitializeRoleSwapDeagle", function()
		STATUS:RegisterStatus("ttt2_role_swap_deagle_reloading", {
			hud = Material("vgui/ttt/hud_icon_deagle.png"),
			type = "bad"
		})
	end)
	
	net.Receive("ttt_role_swap_deagle_miss", function()
		local client = LocalPlayer()
		if not IsValid(client) or not client:IsTerror() or not client:HasWeapon("weapon_ttt2_role_swap_deagle") then
			return
		end
		
		local wep = client:GetWeapon("weapon_ttt2_role_swap_deagle")
		if not IsValid(wep) then
			return
		end
		
		local cooldown = GetConVar("ttt2_role_swap_deagle_refill_time"):GetInt()
		STATUS:AddTimedStatus("ttt2_role_swap_deagle_reloading", cooldown, true)
		timer.Create("ttt2_role_swap_deagle_refill_timer", cooldown, 1, function()
			if not IsValid(wep) then
				return
			end
			
			RoleSwapDeagleRefilled(wep)
		end)
	end)
else
	net.Receive("ttt_role_swap_deagle_refilled", function()
		local wep = net.ReadEntity()
		
		if not IsValid(wep) then
			return
		end
		
		wep:SetClip1(1)
	end)
end
