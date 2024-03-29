if SERVER then
	AddCSLuaFile()
end

CURS_DATA = {}

local function IsInSpecDM(ply)
	if SpecDM and (ply.IsGhost and ply:IsGhost()) then
		return true
	end
	
	return false
end

function CURS_DATA.CanSwapRoles(ply, tgt, dist)
	local ply_is_valid = IsValid(ply) and ply:IsPlayer() and ply:Alive() and not IsInSpecDM(ply) and ply:GetSubRole() == ROLE_CURSED
	local tgt_is_valid = IsValid(tgt) and tgt:IsPlayer() and tgt:Alive() and not IsInSpecDM(tgt) and tgt.curs_last_tagged == nil
	local det_allowed = GetConVar("ttt2_cursed_affect_det"):GetBool()
	
	if GetRoundState() ~= ROUND_ACTIVE or not ply_is_valid or not tgt_is_valid or dist > GetConVar("ttt2_cursed_tag_dist"):GetInt() then
		return false
	end
	
	if not det_allowed and (tgt:GetBaseRole() == ROLE_DETECTIVE or tgt:GetSubRole() == ROLE_DEFECTIVE) then
		return false
	end
	
	return true
end

if SERVER then
	local function IsStickyTeam(team)
		--A hack. True if the supported team is not to be altered for balancing reasons.
		if (DOPPELGANGER and team == TEAM_DOPPELGANGER) or (COPYCAT and team == TEAM_COPYCAT) then
			return true
		end
		
		return false
	end
	
	function CURS_DATA.SwapRoles(old_cursed, tgt)
		local old_cursed_role = old_cursed:GetSubRole()
		local old_cursed_team = old_cursed:GetTeam()
		local backsies_timer_len = GetConVar("ttt2_cursed_backsies_timer"):GetInt()
		
		--Return early if both players have the same role and team, making sure to inform the tagger so they don't think the role is broken
		--Edge case: Break off early if a Dop!Cursed tries to swap with a regular Cursed, as a Dop!Cursed can't lose their team.
		--  In general, a player with a "sticky team" should not swap teams with another.
		if old_cursed_role == tgt:GetSubRole() and (old_cursed_team == tgt:GetTeam() or IsStickyTeam(old_cursed_team) or IsStickyTeam(tgt:GetTeam())) then
			LANG.Msg(old_cursed, "SAME_" .. CURSED.name, nil, MSG_MSTACK_WARN)
			return false
		end
		
		--Immediately mark the Cursed with no backsies to prevent a counterswap.
		old_cursed.curs_last_tagged = tgt:SteamID64()
		
		--Give the Cursed their new role/team first so as to not accidentally end the game due to preventWin
		if not IsStickyTeam(old_cursed_team) then
			old_cursed:SetRole(tgt:GetSubRole(), tgt:GetTeam())
			tgt:SetRole(old_cursed_role, old_cursed_team)
		else
			--Edge case: If a Dop!Cursed tags a player, they shall keep their team, but change roles.
			--This is done because otherwise a Dop!Cursed is mechanically the same as a normal Cursed, due to preventWin making them useless.
			--This method is more fun for the Dop.
			--The same logic applies for Copy!Cursed, who otherwise would effectively remove the Copycat role from the game upon using the Cursed's role swap ability.
			old_cursed:SetRole(tgt:GetSubRole(), old_cursed_team)
			
			--Hardcode the tgt's team to TEAM_NONE, so that they are falsely lead to believe that they weren't tagged by a Doppelganger.
			tgt:SetRole(old_cursed_role, TEAM_NONE)
		end
		SendFullStateUpdate()
		
		--Now that the roles/teams have been switched, unmark any player that is registered as having tagged the previous Cursed
		for _, ply in ipairs(player.GetAll()) do
			if ply.curs_last_tagged == old_cursed:SteamID64() then
				ply.curs_last_tagged = nil
				STATUS:RemoveStatus(ply, "ttt2_curs_no_backsies")
			end
		end
		
		--Finally take care of ensuring no backsies occur.
		if backsies_timer_len > 0 then
			STATUS:AddTimedStatus(old_cursed, "ttt2_curs_no_backsies", backsies_timer_len, true)
			timer.Simple(backsies_timer_len, function()
				old_cursed.curs_last_tagged = nil
			end)
		else
			STATUS:AddStatus(old_cursed, "ttt2_curs_no_backsies")
		end
		
		return true
	end

	function CURS_DATA.AttemptSwap(ply, tgt, dist)
		local did_swap = false
		local det_allowed = GetConVar("ttt2_cursed_affect_det"):GetBool()
		
		if CURS_DATA.CanSwapRoles(ply, tgt, dist) then
			did_swap = CURS_DATA.SwapRoles(ply, tgt)
		elseif tgt.curs_last_tagged ~= nil then
			if tgt.curs_last_tagged == ply:SteamID64() then
				LANG.Msg(ply, "NO_BACKSIES_" .. CURSED.name, nil, MSG_MSTACK_WARN)
			else
				LANG.Msg(ply, "PROT_" .. CURSED.name, {name = tgt:GetName()}, MSG_MSTACK_WARN)
			end
		elseif not det_allowed and IsValid(tgt) and tgt:IsPlayer() and tgt:Alive() and not IsInSpecDM(tgt) and (tgt:GetBaseRole() == ROLE_DETECTIVE or tgt:GetSubRole() == ROLE_DEFECTIVE) then
			LANG.Msg(ply, "NO_DET_" .. CURSED.name, nil, MSG_MSTACK_WARN)
		end
		
		return did_swap
	end
	
	local function ResetAllCursedDataForServer()
		for _, ply in ipairs(player.GetAll()) do
			ply.curs_last_tagged = nil
			STATUS:RemoveStatus(ply, "ttt2_curs_no_backsies")
		end
	end
	hook.Add("TTTEndRound", "ResetCursedForServerOnEndRound", ResetAllCursedDataForServer)
	hook.Add("TTTBeginRound", "ResetCursedForServerOnBeginRound", ResetAllCursedDataForServer)
end

if CLIENT then
	hook.Add("Initialize", "InitializeCursedData", function()
		STATUS:RegisterStatus("ttt2_curs_no_backsies", {
			hud = Material("vgui/ttt/icon_cursed_no_backsies.png"),
			type = "good"
		})
	end)
end