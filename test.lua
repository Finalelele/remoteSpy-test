-- [[ KRALLDEN SPY v9.2.1 - FULL SOURCE - SELF TOP & DYNAMIC FILTER RESET ]] --

local player = game:GetService("Players").LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

if playerGui:FindFirstChild("KralldenSpyUI") then playerGui.KralldenSpyUI:Destroy() end

local ScreenGui = Instance.new("ScreenGui", playerGui)
ScreenGui.Name = "KralldenSpyUI"; ScreenGui.ResetOnSpawn = false; ScreenGui.DisplayOrder = 2147483647

local Main = Instance.new("Frame", ScreenGui)
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 20); Main.Size = UDim2.new(0, 820, 0, 440)
Main.Position = UDim2.new(0.5, -410, 0.5, -220); Main.Active = true; Main.Draggable = true; Main.BorderSizePixel = 0

local MainMemory, PathFilter, ManualBannedPaths = {}, {}, {}
local AntiSpamCooldowns, AntiSpamCounts = {}, {}
local selfMode, controlMode, antiSpam = true, true, true
local spyFS, spyFC, spyIS = true, false, false
local currentSelectionGUID, lastCount = nil, 0
local isMin = false

local function generateGUID() return tostring(tick()) .. "-" .. tostring(math.random(1, 100000)) end

local RedListScroll, Scroll, Details, ContentFrame

local function refreshSelectionColors()
    for _, v in pairs(Scroll:GetChildren()) do
        if v:IsA("TextButton") then
            local isSelected = (v:GetAttribute("GUID") == currentSelectionGUID)
            local isSelf = v:GetAttribute("IsSelf")
            v.BackgroundColor3 = isSelected and Color3.fromRGB(100, 50, 200) or (isSelf and Color3.fromRGB(45, 90, 45) or Color3.fromRGB(40, 40, 45))
        end
    end
    for _, v in pairs(RedListScroll:GetChildren()) do
        if v:IsA("TextButton") then
            local isSelected = (v:GetAttribute("GUID") == currentSelectionGUID)
            v.BackgroundColor3 = isSelected and Color3.fromRGB(100, 50, 200) or Color3.fromRGB(100, 35, 35)
        end
    end
end

local function updateRedListUI()
    if not RedListScroll then return end
    for _, v in pairs(RedListScroll:GetChildren()) do if v:IsA("TextButton") then v:Destroy() end end
    for path, data in pairs(ManualBannedPaths) do
        local b = Instance.new("TextButton", RedListScroll)
        b.Size = UDim2.new(1, -6, 0, 25)
        b:SetAttribute("GUID", data.guid)
        b.BackgroundColor3 = (currentSelectionGUID == data.guid) and Color3.fromRGB(100, 50, 200) or Color3.fromRGB(100, 35, 35)
        b.TextColor3 = Color3.new(1,1,1); b.Font = Enum.Font.SourceSansBold; b.TextSize = 10; b.BorderSizePixel = 0
        b.Text = " [X] " .. (path:match("[^%.%[%]]+$") or path)
        
        b.MouseButton1Click:Connect(function() 
            currentSelectionGUID = data.guid
            Details.Text = data.details 
            refreshSelectionColors()
        end)
    end
end

local function fullClear()
    MainMemory, PathFilter, lastCount, currentSelectionGUID = {}, {}, 0, nil
    ManualBannedPaths = {}
    AntiSpamCooldowns, AntiSpamCounts = {}, {}
    if Details then Details.Text = "" end
    if Scroll then for _, v in pairs(Scroll:GetChildren()) do if v:IsA("TextButton") then v:Destroy() end end end
    updateRedListUI()
    refreshSelectionColors()
end

-- HEADER
local Header = Instance.new("Frame", Main)
Header.Size = UDim2.new(1, 0, 0, 35); Header.BackgroundColor3 = Color3.fromRGB(25, 25, 30); Header.ZIndex = 10; Header.BorderSizePixel = 0

local Title = Instance.new("TextLabel", Header)
Title.Size = UDim2.new(0, 200, 1, 0); Title.BackgroundTransparency = 1; Title.Position = UDim2.new(0, 15, 0, 0)
Title.Text = "KRALLDEN SPY v9.2.1"; Title.TextColor3 = Color3.new(1, 1, 1); Title.Font = Enum.Font.SourceSansBold; Title.TextSize = 16; Title.ZIndex = 11; Title.TextXAlignment = 0

local MinBtn = Instance.new("TextButton", Header)
MinBtn.Size = UDim2.new(0, 45, 0, 35); MinBtn.Position = UDim2.new(1, -45, 0, 0); MinBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 180); MinBtn.Text = "_"; MinBtn.TextColor3 = Color3.new(1, 1, 1); MinBtn.TextSize = 22; MinBtn.ZIndex = 12; MinBtn.BorderSizePixel = 0

local function createHeaderBtn(text, offset, color)
    local b = Instance.new("TextButton", Header)
    b.Size = UDim2.new(0, 100, 0, 24); b.Position = UDim2.new(1, offset, 0.5, -12); b.BackgroundColor3 = color; b.Text = text; b.TextColor3 = Color3.new(1,1,1); b.Font = Enum.Font.SourceSansBold; b.TextSize = 11; b.ZIndex = 11; b.BorderSizePixel = 0
    return b
end

local ControlBtn = createHeaderBtn("CONTROL: ON", -150, Color3.fromRGB(150, 50, 255))
local SelfBtn = createHeaderBtn("SELF: ON", -235, Color3.fromRGB(45, 90, 45))
SelfBtn.Size = UDim2.new(0, 80, 0, 24)
local AntiSpamBtn = createHeaderBtn("ANTI-SPAM: ON", -345, Color3.fromRGB(180, 150, 40))
AntiSpamBtn.Visible = false
local BlockBtn = createHeaderBtn("BLOCK EVENT", -455, Color3.fromRGB(150, 50, 50))
BlockBtn.Visible = false

ContentFrame = Instance.new("Frame", Main)
ContentFrame.Name = "ContentFrame"; ContentFrame.Size = UDim2.new(1, 0, 1, -35); ContentFrame.Position = UDim2.new(0, 0, 0, 35); ContentFrame.BackgroundTransparency = 1; ContentFrame.ClipsDescendants = true

Scroll = Instance.new("ScrollingFrame", ContentFrame)
Scroll.Position = UDim2.new(0, 8, 0, 8); Scroll.Size = UDim2.new(0, 190, 1, -16); Scroll.BackgroundColor3 = Color3.fromRGB(20, 20, 25); Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; Scroll.BorderSizePixel = 0
Instance.new("UIListLayout", Scroll).SortOrder = Enum.SortOrder.LayoutOrder

Details = Instance.new("TextBox", ContentFrame)
Details.Position = UDim2.new(0, 205, 0, 8); Details.Size = UDim2.new(0, 448, 0, 255); Details.BackgroundColor3 = Color3.fromRGB(10, 10, 12); Details.TextColor3 = Color3.new(1, 1, 1); Details.MultiLine = true; Details.TextWrapped = true; Details.TextEditable = false; Details.Font = Enum.Font.Code; Details.TextSize = 12; Details.TextXAlignment = 0; Details.TextYAlignment = 0

local BanListTitle = Instance.new("TextLabel", ContentFrame)
BanListTitle.Size = UDim2.new(0, 150, 0, 20); BanListTitle.Position = UDim2.new(0, 662, 0, 125); BanListTitle.BackgroundTransparency = 1
BanListTitle.Text = "BAN LIST"; BanListTitle.TextColor3 = Color3.fromRGB(255, 100, 100); BanListTitle.Font = Enum.Font.SourceSansBold; BanListTitle.TextSize = 14

RedListScroll = Instance.new("ScrollingFrame", ContentFrame)
RedListScroll.Position = UDim2.new(0, 662, 0, 145); RedListScroll.Size = UDim2.new(0, 150, 0, 250); RedListScroll.BackgroundColor3 = Color3.fromRGB(30, 15, 15); RedListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; RedListScroll.BorderSizePixel = 0
Instance.new("UIListLayout", RedListScroll).SortOrder = Enum.SortOrder.LayoutOrder

local function getSafePath(obj)
    local p = ""; pcall(function() local t = obj; while t and t ~= game do local n = tostring(t.Name); p = (n:match("[%s%W]") and '["'..n..'"]' or n) .. (p ~= "" and "." .. p or ""); t = t.Parent end end)
    return p ~= "" and "game." .. p:gsub("%.%[", "[") or "game.NilObject"
end

local function addLog(rem, args, isSelf, typeLabel)
    if isSelf and not selfMode then return end
    if (typeLabel == "FS" and not spyFS) or (typeLabel == "FC" and not spyFC) or (typeLabel == "IS" and not spyIS) then return end
    
    local eventPath = getSafePath(rem)
    if ManualBannedPaths[eventPath] then return end

    local function parseValue(v, d)
        d = d or 0; if d > 4 then return "..." end
        local t = type(v)
        if t == "string" then return '"' .. v .. '"'
        elseif t == "table" then
            local isArray, count = true, 0
            for k, val in pairs(v) do count = count + 1; if type(k) ~= "number" or k ~= count then isArray = false break end end
            local res, i = "{", 0
            for k, val in pairs(v) do i = i + 1; if i > 15 then res = res .. "... " break end
                if isArray then res = res .. parseValue(val, d + 1) .. ", "
                else local key = type(k) == "number" and "["..k.."]" or '["'..tostring(k)..'"]'
                    res = res .. key .. " = " .. parseValue(val, d + 1) .. ", "
                end
            end
            local result = res:gsub(", $", "") .. "}"
            return result == "}" and "{}" or result
        elseif t == "userdata" then
            local tn = typeof(v)
            if tn == "CFrame" then return "CFrame.new(" .. tostring(v) .. ")"
            elseif tn == "Vector3" then return "Vector3.new(" .. tostring(v) .. ")"
            elseif tn == "Color3" then return "Color3.new(" .. tostring(v) .. ")"
            elseif tn == "Instance" then return getSafePath(v) end
            return tostring(v)
        else return tostring(v) end
    end

    local argList = {}
    for i, v in ipairs(args) do table.insert(argList, parseValue(v)) end
    local finalArgsStr = table.concat(argList, ", ")
    
    local filterKey = ""
    if isSelf then
        filterKey = "SELF_" .. (selfMode and eventPath or (eventPath .. "|" .. finalArgsStr))
    else
        filterKey = "CTRL_" .. (controlMode and eventPath or (eventPath .. "|" .. finalArgsStr))
    end

    if PathFilter[filterKey] then return end

    local methodName = (typeLabel == "IS" and "InvokeServer" or "FireServer")
    local logDetails = string.format("Type: %s\n\nPath: %s\n\nArgs: %s\n\nScript:\n%s:%s(%s)", typeLabel, eventPath, finalArgsStr, eventPath, methodName, finalArgsStr)

    if not isSelf and not controlMode and antiSpam then
        if (tick() - (AntiSpamCooldowns[eventPath] or 0)) < 0.4 then
            AntiSpamCounts[eventPath] = (AntiSpamCounts[eventPath] or 0) + 1
            if AntiSpamCounts[eventPath] >= 4 then
                ManualBannedPaths[eventPath] = {guid = generateGUID(), details = "AUTO-BANNED BY ANTI-SPAM\n\n" .. logDetails}
                local cleanMemory = {}
                for _, m in ipairs(MainMemory) do
                    if not m.fullText:match("Path: " .. eventPath:gsub("[%[%]%(%)%.%+%-%*%?%^%$%%]", "%%%1")) then
                        table.insert(cleanMemory, m)
                    end
                end
                MainMemory = cleanMemory; currentSelectionGUID = nil; lastCount = -1; updateRedListUI(); return 
            end
        else AntiSpamCounts[eventPath] = 0 end
        AntiSpamCooldowns[eventPath] = tick()
    end

    local data = { guid = generateGUID(), name = tostring(rem.Name), type = typeLabel, isSelf = isSelf, fullText = logDetails }
    PathFilter[filterKey] = true
    table.insert(MainMemory, 1, data)
end

-- HOOKS
local mt = getrawmetatable(game); local old = mt.__namecall; setreadonly(mt, false)
mt.__namecall = newcclosure(function(self, ...)
    local m = getnamecallmethod(); local a = {...}; local s = checkcaller()
    if m:lower() == "fireserver" then task.spawn(addLog, self, a, s, "FS")
    elseif m:lower() == "fireclient" then task.spawn(addLog, self, a, s, "FC")
    elseif m:lower() == "invokeserver" then task.spawn(addLog, self, a, s, "IS") end
    return old(self, ...)
end); setreadonly(mt, true)

-- INTERACTION
ControlBtn.MouseButton1Click:Connect(function() 
    controlMode = not controlMode; fullClear()
    ControlBtn.Text = "CONTROL: "..(controlMode and "ON" or "OFF")
    ControlBtn.BackgroundColor3 = controlMode and Color3.fromRGB(150, 50, 255) or Color3.fromRGB(80, 80, 85)
    AntiSpamBtn.Visible = not controlMode; BlockBtn.Visible = not controlMode
end)

BlockBtn.MouseButton1Click:Connect(function()
    if currentSelectionGUID then
        for i, d in ipairs(MainMemory) do
            if d.guid == currentSelectionGUID and not d.isSelf then
                local p = d.fullText:match("Path: (.-)\n")
                if p then
                    ManualBannedPaths[p] = {guid = d.guid, details = "MANUAL BANNED:\n\n" .. d.fullText}
                    local nM = {}; for _, m in ipairs(MainMemory) do if not m.fullText:match("Path: " .. p:gsub("[%[%]%(%)%.%+%-%*%?%^%$%%]", "%%%1")) then table.insert(nM, m) end end
                    MainMemory = nM; lastCount = -1; currentSelectionGUID = nil; updateRedListUI(); Details.Text = "Banned."
                end; break
            elseif d.guid == currentSelectionGUID and d.isSelf then
                Details.Text = "Cannot block Self-Events."
            end
        end
    end
end)

MinBtn.MouseButton1Click:Connect(function()
    isMin = not isMin
    local curX, curY = Main.AbsolutePosition.X + Main.AbsoluteSize.X, Main.AbsolutePosition.Y
    if isMin then
        ContentFrame.Visible = false; ControlBtn.Visible = false; SelfBtn.Visible = false; AntiSpamBtn.Visible = false; BlockBtn.Visible = false
        Main:TweenSizeAndPosition(UDim2.new(0, 250, 0, 35), UDim2.new(0, curX - 250, 0, curY), "Out", "Quad", 0.15, true); MinBtn.Text = "+"
    else
        Main:TweenSizeAndPosition(UDim2.new(0, 820, 0, 440), UDim2.new(0, curX - 820, 0, curY), "Out", "Quad", 0.15, true, function()
            ContentFrame.Visible = true; ControlBtn.Visible = true; SelfBtn.Visible = true; if not controlMode then AntiSpamBtn.Visible = true; BlockBtn.Visible = true end
        end); MinBtn.Text = "_"; lastCount = -1
    end
end)

-- RENDER LOOP (С ПРИОРИТЕТОМ SELF ВВЕРХУ)
task.spawn(function()
    while task.wait(0.5) do
        if not ContentFrame or not ContentFrame.Visible or #MainMemory == lastCount then continue end
        lastCount = #MainMemory; for _, v in pairs(Scroll:GetChildren()) do if v:IsA("TextButton") then v:Destroy() end end
        
        local sortedMemory = {}
        -- Сначала добавляем Self ивенты
        for _, d in ipairs(MainMemory) do if d.isSelf then table.insert(sortedMemory, d) end end
        -- Затем добавляем обычные
        for _, d in ipairs(MainMemory) do if not d.isSelf then table.insert(sortedMemory, d) end end

        for i, d in ipairs(sortedMemory) do
            local b = Instance.new("TextButton", Scroll); b.Size = UDim2.new(1, -6, 0, 30); b.LayoutOrder = i
            b.Text = string.format("[%s]%s %s", d.type, (d.isSelf and " [S]" or ""), d.name)
            b:SetAttribute("GUID", d.guid); b:SetAttribute("IsSelf", d.isSelf)
            b.BackgroundColor3 = (currentSelectionGUID == d.guid) and Color3.fromRGB(100, 50, 200) or (d.isSelf and Color3.fromRGB(45, 90, 45) or Color3.fromRGB(40, 40, 45))
            b.TextColor3 = Color3.new(1,1,1); b.BorderSizePixel = 0
            b.MouseButton1Click:Connect(function()
                currentSelectionGUID = d.guid; Details.Text = d.fullText
                refreshSelectionColors()
            end)
        end
    end
end)

local function createBotBtn(text, pos, color)
    local b = Instance.new("TextButton", ContentFrame); b.Size = UDim2.new(0, 220, 0, 58); b.Position = pos; b.BackgroundColor3 = color; b.Text = text; b.TextColor3 = Color3.new(1,1,1); b.Font = Enum.Font.SourceSansBold; b.TextSize = 14; b.BorderSizePixel = 0; return b
end

createBotBtn("COPY ARGS", UDim2.new(0, 205, 0.68, 0), Color3.fromRGB(45, 90, 45)).MouseButton1Click:Connect(function() 
    local args = Details.Text:match("Args: (.-)\n\nScript")
    if args then setclipboard(args); print("[KRALLDEN] Args copied!") end
end)

createBotBtn("COPY SCRIPT", UDim2.new(0, 205, 0.83, 0), Color3.fromRGB(60, 60, 120)).MouseButton1Click:Connect(function() 
    local code = Details.Text:match("Script:\n(.*)")
    if code then setclipboard(code); print("[KRALLDEN] Script copied!") end
end)

createBotBtn("CLEAR LOG", UDim2.new(0, 432, 0.68, 0), Color3.fromRGB(80, 80, 85)).MouseButton1Click:Connect(fullClear)

createBotBtn("EXECUTE", UDim2.new(0, 432, 0.83, 0), Color3.fromRGB(120, 60, 60)).MouseButton1Click:Connect(function() 
    local code = Details.Text:match("Script:\n(.*)")
    if code and code ~= "" then 
        local func, err = loadstring(code)
        if func then task.spawn(func); print("[KRALLDEN] Executing...") else warn("[KRALLDEN] Error: " .. tostring(err)) end
    end 
end)

SelfBtn.MouseButton1Click:Connect(function() 
    selfMode = not selfMode
    -- [[ СБРОС ФИЛЬТРОВ ДЛЯ SELF ПРИ ПЕРЕКЛЮЧЕНИИ ]] --
    local newFilters = {}
    for k, v in pairs(PathFilter) do if not k:match("^SELF_") then newFilters[k] = v end end
    PathFilter = newFilters
    
    SelfBtn.Text = "SELF: "..(selfMode and "ON" or "OFF")
    SelfBtn.BackgroundColor3 = selfMode and Color3.fromRGB(45, 90, 45) or Color3.fromRGB(150, 50, 50) 
end)

AntiSpamBtn.MouseButton1Click:Connect(function() 
    antiSpam = not antiSpam; AntiSpamBtn.Text = "ANTI-SPAM: "..(antiSpam and "ON" or "OFF")
    AntiSpamBtn.BackgroundColor3 = antiSpam and Color3.fromRGB(180, 150, 40) or Color3.fromRGB(80, 80, 85) 
end)

local function createTypeBtn(text, pos, state, color, varName)
    local b = Instance.new("TextButton", ContentFrame); b.Size = UDim2.new(0, 150, 0, 35); b.Position = pos; b.BackgroundColor3 = state and color or Color3.fromRGB(40, 40, 45); b.Text = text; b.TextColor3 = Color3.new(1,1,1); b.Font = Enum.Font.SourceSansBold; b.TextSize = 12; b.BorderSizePixel = 0
    b.MouseButton1Click:Connect(function()
        if varName == "FS" then spyFS = not spyFS elseif varName == "FC" then spyFC = not spyFC elseif varName == "IS" then spyIS = not spyIS end
        local newState = (varName == "FS" and spyFS or varName == "FC" and spyFC or spyIS)
        b.Text = varName.." SPY: "..(newState and "ON" or "OFF"); b.BackgroundColor3 = newState and color or Color3.fromRGB(40, 40, 45)
    end)
end
createTypeBtn("FS SPY: ON", UDim2.new(0, 662, 0, 8), spyFS, Color3.fromRGB(150, 50, 255), "FS")
createTypeBtn("FC SPY: OFF", UDim2.new(0, 662, 0, 48), spyFC, Color3.fromRGB(50, 150, 255), "FC")
createTypeBtn("IS SPY: OFF", UDim2.new(0, 662, 0, 88), spyIS, Color3.fromRGB(255, 150, 50), "IS")
