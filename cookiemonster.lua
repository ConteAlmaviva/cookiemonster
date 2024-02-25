addon.author   = 'Almavivaconte';
addon.name     = 'CookieMonster';
addon.version  = '0.0.1';

local manaJobIDs = {
    3, -- WHM
    4, -- BLM
    5, -- RDM
    15 -- SMN
}

local GINGER_COOKIE = 4394
local WIZARD_COOKIE = 4576
local cm_on = true;
local checked_for_cookies = false;

require('common');

local function SendHealPacket()
    local HealPacket = struct.pack('bbbbbbbb', 0xE8, 0, 0, 0, 1, 0, 0, 0):totable();
    AshitaCore:GetPacketManager():AddOutgoingPacket(0xE8, HealPacket);
end

local function reset_check()
    checked_for_cookies = false
end

local function heal_on()
    selfIndex = AshitaCore:GetMemoryManager():GetParty():GetMemberTargetIndex(0);
    currentStatus = GetEntity(selfIndex).Status;
    if currentStatus ~= 33 then
        SendHealPacket();
    end
end

local function eat_food()
    local has_wizard = false;
    local has_ginger = false;
    checked_for_cookies = true;
    local inventory = AshitaCore:GetMemoryManager():GetInventory();
    for j = 0, inventory:GetContainerCountMax(0), 1 do
        if inventory:GetContainerItem(0, j).Id == WIZARD_COOKIE then
            has_wizard = true;
            break;
        end
        if inventory:GetContainerItem(0, j).Id == GINGER_COOKIE then
            has_ginger = true;
            break;
        end
    end
    if has_wizard then
        AshitaCore:GetChatManager():QueueCommand(1, "/item \"Wizard Cookie\" <me>");
    elseif has_ginger then
        AshitaCore:GetChatManager():QueueCommand(1, "/item \"Ginger Cookie\" <me>");
    else
        SendHealPacket();
        ashita.tasks.once(10, reset_check);
    end
end

ashita.events.register('command', 'command_cb', function (e)
    -- Ensure we should handle this command..
    local args = e.command:args();
    if (args[1] == '/cmoff' or args[1] == '/cmon') then
        cm_on = not cm_on
        if cm_on then
            print("\30\201[\30\82CookieMonster\30\201]\31\255 CookieMonster enabled; /ckm will check for current job and active food and eat a cookie before resting if applicable.")
        else
            print("\30\201[\30\82CookieMonster\30\201]\31\255 CookieMonster disabled; /ckm will just rest.")
        end
        return true;
    end
    return false;
end);

ashita.events.register('packet_out', 'packet_out_cb', function (e)
	
	if (e.id == 0xE8) then
        heal_type = struct.unpack('b', e.data, 0x05);
        if(heal_type ~= 2 and not checked_for_cookies) then
            if cm_on then
                selfIndex = AshitaCore:GetMemoryManager():GetParty():GetMemberTargetIndex(0);
                currentStatus = GetEntity(selfIndex).Status;
                if currentStatus ~= 33 then
                    local hasFood = false;
                    local buffs = AshitaCore:GetMemoryManager():GetPlayer():GetBuffs();
                    if buffs ~= nil then
                        for k,v in pairs(buffs) do
                            if v == 251 then
                                hasFood = true;
                            end
                        end
                    end
                    job = AshitaCore:GetMemoryManager():GetPlayer():GetMainJob();
                    if not hasFood then
                        for k,v in pairs(manaJobIDs) do
                            if job == v then
                                e.blocked = true;
                                -- You're a mana-using job with no food effect, will eat cookie and rest
                                eat_food();
                                ashita.tasks.once(3, SendHealPacket)
                            end
                        end
                        if job == 17 then
                            if AshitaCore:GetMemoryManager():GetPlayer():GetSubJob() == 3 then
                                e.blocked = true;
                                -- You're a COR/WHM with no food effect, will eat cookie and rest
                                eat_food();
                                ashita.tasks.once(3, SendHealPacket)
                            end
                        end
                    end
                end
                return false;
            end
        end
    end
	return false;
end);