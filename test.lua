-- [[ KRALLDEN SPY v9.4.9 - CLEAN VERSION WITH ANTI-HIDE & FEEDBACK FIX ]] --

local player = game:GetService("Players").LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local TextService = game:GetService("TextService")

-- Очистка старых версий (безопасно для Delta)
if playerGui:FindFirstChild("KralldenSpyUI") then playerGui.KralldenSpyUI:Destroy() end
for _, gui in ipairs(game.CoreGui:GetChildren()) do
    pcall(function()
        if gui.Name == "KralldenSpyUI" then
            gui:Destroy()
        elseif gui:FindFirstChild("KralldenSpyUI") then
            gui.KralldenSpyUI:Destroy()
        end
    end)
end

local targetParent = (gethui and gethui()) or (game:GetService("CoreGui"):FindFirstChild("RobloxGui")) or playerGui
local ScreenGui = Instance.new("ScreenGui", targetParent)
ScreenGui.Name = "KralldenSpyUI"; ScreenGui.ResetOnSpawn = false; ScreenGui.DisplayOrder = 10; ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Anti-Hide (Оптимизированный цикл)
task.spawn(function()
    while task.wait(1) do 
        if ScreenGui and ScreenGui.Parent and not ScreenGui.Enabled then
            ScreenGui.Enabled = true
        end
    end
end)

local Main = Instance.new("Frame", ScreenGui)
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 20); Main.Size = UDim2.new(0, 820, 0, 440)
Main.Position = UDim2.new(0.5, -410, 0.5, -220); Main.Active = true; Main.Draggable = true; Main.BorderSizePixel = 0

local MainMemory, PathFilter, ManualBannedPaths = {}, {}, {}
local AntiSpamCooldowns, AntiSpamCounts = {}, {}
local selfMode, controlMode, antiSpam = true, true, true
local spyFS, spyFC, spyIS = true, false, false
local currentSelectionGUID, lastCount = nil, 0
local isMin = false
local sortArgs = false

local function generateGUID() return tostring(tick()) .. "-" .. tostring(math.random(1, 100000)) end

local RedListScroll, Scroll, DetailsScroll, Details, ContentFrame

-- Функция фидбека
local activeFeedbacks = {}
local function feedback(button, tempText)
    if not button or activeFeedbacks[button] then return end
    activeFeedbacks[button] = true
    local oldText = button.Text
    button.Text = tempText
    task.delay(1, function()
        if button and button.Parent then 
            button.Text = oldText 
            activeFeedbacks[button] = nil
        end
    end)
end

local function refreshSelectionColors()
    if not Scroll or not RedListScroll then return end
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

local function updateDetailsView()
    if not currentSelectionGUID then
        Details.Text = ""
        return
    end
    for _, d in ipairs(MainMemory) do
        if d.guid == currentSelectionGUID then
            Details.Text = sortArgs and d.fullTextPretty or d.fullText
            return
        end
    end
    for _, data in pairs(ManualBannedPaths) do
        if data.guid == currentSelectionGUID then
            Details.Text = sortArgs and (data.detailsPretty or data.details) or data.details
            return
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
        b:SetAttribute("Path", path)
        b.BackgroundColor3 = (currentSelectionGUID == data.guid) and Color3.fromRGB(100, 50, 200) or Color3.fromRGB(100, 35, 35)
        b.TextColor3 = Color3.new(1,1,1); b.Font = Enum.Font.SourceSansBold; b.TextSize = 10; b.BorderSizePixel = 0
        b.Text = " [X] " .. (path:match("[^%.%[%]]+$") or path)
        
        b.MouseButton1Click:Connect(function() 
            currentSelectionGUID = data.guid
            updateDetailsView()
            refreshSelectionColors()
        end)
    end
end

-- HEADER
local Header = Instance.new("Frame", Main)
Header.Size = UDim2.new(1, 0, 0, 35); Header.BackgroundColor3 = Color3.fromRGB(25, 25, 30); Header.ZIndex = 10; Header.BorderSizePixel = 0

local Title = Instance.new("TextLabel", Header)
Title.Size = UDim2.new(0, 200, 1, 0); Title.BackgroundTransparency = 1; Title.Position = UDim2.new(0, 15, 0, 0)
Title.Text = "KRALLDEN SPY v9.4.9"; Title.TextColor3 = Color3.new(1, 1, 1); Title.Font = Enum.Font.SourceSansBold; Title.TextSize = 16; Title.ZIndex = 11; Title.TextXAlignment = 0

local MinBtn = Instance.new("TextButton", Header)
MinBtn.Size = UDim2.new(0, 45, 0, 35); MinBtn.Position = UDim2.new(1, -45, 0, 0); MinBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 180); MinBtn.Text = "_"; MinBtn.TextColor3 = Color3.new(1, 1, 1); MinBtn.TextSize = 22; MinBtn.ZIndex = 12; MinBtn.BorderSizePixel = 0

local function createHeaderBtn(text, offset, color, sizeX)
    local b = Instance.new("TextButton", Header)
    b.Size = UDim2.new(0, sizeX or 100, 0, 24); b.Position = UDim2.new(1, offset, 0.5, -12); b.BackgroundColor3 = color; b.Text = text; b.TextColor3 = Color3.new(1,1,1); b.Font = Enum.Font.SourceSansBold; b.TextSize = 11; b.ZIndex = 11; b.BorderSizePixel = 0
    return b
end

local ControlBtn = createHeaderBtn("CONTROL: ON", -150, Color3.fromRGB(0, 170, 190))
local SelfBtn = createHeaderBtn("SELF: ON", -235, Color3.fromRGB(45, 90, 45), 80)
local DelBtn = createHeaderBtn("DEL BTN", -310, Color3.fromRGB(200, 100, 0), 70)
local AntiSpamBtn = createHeaderBtn("ANTI-SPAM: ON", -420, Color3.fromRGB(180, 150, 40))
AntiSpamBtn.Visible = false
local BlockBtn = createHeaderBtn("BLOCK EVENT", -530, Color3.fromRGB(150, 50, 50))
BlockBtn.Visible = false

ContentFrame = Instance.new("Frame", Main)
ContentFrame.Name = "ContentFrame"; ContentFrame.Size = UDim2.new(1, 0, 1, -35); ContentFrame.Position = UDim2.new(0, 0, 0, 35); ContentFrame.BackgroundTransparency = 1; ContentFrame.ClipsDescendants = true

Scroll = Instance.new("ScrollingFrame", ContentFrame)
Scroll.Position = UDim2.new(0, 8, 0, 8); Scroll.Size = UDim2.new(0, 190, 1, -16); Scroll.BackgroundColor3 = Color3.fromRGB(20, 20, 25); Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 4
Instance.new("UIListLayout", Scroll).SortOrder = Enum.SortOrder.LayoutOrder

-- ИСПРАВЛЕННЫЙ БЛОК DETAILS (Scroll + Auto-Sizing)
DetailsScroll = Instance.new("ScrollingFrame", ContentFrame)
DetailsScroll.Position = UDim2.new(0, 205, 0, 8)
DetailsScroll.Size = UDim2.new(0, 448, 0, 255)
DetailsScroll.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
DetailsScroll.BorderSizePixel = 0
DetailsScroll.ScrollBarThickness = 6
DetailsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
DetailsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

local DetailsPadding = Instance.new("UIPadding", DetailsScroll)
DetailsPadding.PaddingTop = UDim.new(0, 8)
DetailsPadding.PaddingBottom = UDim.new(0, 8)
DetailsPadding.PaddingLeft = UDim.new(0, 8)
DetailsPadding.PaddingRight = UDim.new(0, 8)

-- Используем TextLabel для надежного отображения, а TextBox для копирования
Details = Instance.new("TextBox", DetailsScroll)
Details.Name = "LogDisplay"
Details.Size = UDim2.new(1, 0, 0, 0) 
Details.AutomaticSize = Enum.AutomaticSize.Y -- Заставляет бокс расти вниз бесконечно
Details.BackgroundTransparency = 1
Details.TextColor3 = Color3.new(1, 1, 1)
Details.MultiLine = true
Details.TextWrapped = true
Details.TextEditable = true -- Оставляем возможность выделения/правки
Details.Font = Enum.Font.Code
Details.TextSize = 12
Details.TextXAlignment = Enum.TextXAlignment.Left
Details.TextYAlignment = Enum.TextYAlignment.Top
Details.ClearTextOnFocus = false

local BanListTitle = Instance.new("TextLabel", ContentFrame)
BanListTitle.Size = UDim2.new(0, 150, 0, 20); BanListTitle.Position = UDim2.new(0, 662, 0, 125); BanListTitle.BackgroundTransparency = 1
BanListTitle.Text = "BAN LIST"; BanListTitle.TextColor3 = Color3.fromRGB(255, 100, 100); BanListTitle.Font = Enum.Font.SourceSansBold; BanListTitle.TextSize = 14

RedListScroll = Instance.new("ScrollingFrame", ContentFrame)
RedListScroll.Position = UDim2.new(0, 662, 0, 145); RedListScroll.Size = UDim2.new(0, 150, 0, 250); RedListScroll.BackgroundColor3 = Color3.fromRGB(30, 15, 15); RedListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; RedListScroll.BorderSizePixel = 0
Instance.new("UIListLayout", RedListScroll).SortOrder = Enum.SortOrder.LayoutOrder

-- SMART PARSER
local function getSafePath(obj)
    local p = ""; 
    local ok, err = pcall(function() 
        local t = obj; 
        while t and t ~= game do 
            local n = tostring(t.Name); 
            local safeName = (n:match("^%d") or n:match("[%s%W]")) and '["'..n..'"]' or n
            
            if p == "" then p = safeName
            else
                if safeName:sub(1,1) == "[" then p = safeName .. "." .. p
                else p = safeName .. "." .. p end
            end
            t = t.Parent 
        end 
    end)
    local finalPath = "game." .. p
    return finalPath:gsub("%.%[", "[") 
end

local function addLog(rem, args, isSelf, typeLabel)
    if (typeLabel == "FS" and not spyFS) or (typeLabel == "FC" and not spyFC) or (typeLabel == "IS" and not spyIS) then return end
    
    local eventPath = getSafePath(rem)
    if not isSelf and ManualBannedPaths[eventPath] then return end

    local function parseValue(v, d, pretty, indent)
        d = d or 0; indent = indent or 0; if d > 128 then return "..." end
        local t = type(v)
        if t == "string" then return '"' .. v .. '"'
        elseif t == "table" then
            local isArray, count = true, 0
            for k, val in pairs(v) do count = count + 1; if type(k) ~= "number" or k ~= count then isArray = false break end end
            local res = "{"
            if pretty then res = res .. "\n" end
            local i = 0
            for k, val in pairs(v) do
                i = i + 1; if i > 100000 then res = res .. (pretty and string.rep("  ", indent + 1) or "") .. "..." .. (pretty and "\n" or " ") break end
                local vStr = parseValue(val, d + 1, pretty, indent + 1)
                if isArray then
                    res = res .. (pretty and string.rep("  ", indent + 1) or "") .. vStr .. "," .. (pretty and "\n" or " ")
                else
                    local key = type(k) == "number" and "["..k.."]" or '["'..tostring(k)..'"]'
                    res = res .. (pretty and string.rep("  ", indent + 1) or "") .. key .. " = " .. vStr .. "," .. (pretty and "\n" or " ")
                end
            end
            if pretty then
                res = res:gsub(",\n$", "\n") .. string.rep("  ", indent) .. "}"
            else
                res = res:gsub(", $", "") .. "}"
            end
            return res == "{}" and "{}" or res
        elseif t == "userdata" then
            local tn = typeof(v)
            if tn == "CFrame" then return "CFrame.new(" .. tostring(v) .. ")"
            elseif tn == "Vector3" then return "Vector3.new(" .. tostring(v) .. ")"
            elseif tn == "Color3" then return "Color3.new(" .. tostring(v) .. ")"
            elseif tn == "Instance" then return getSafePath(v) end
            return tostring(v)
        else return tostring(v) end
    end

    local argList, argListPretty = {}, {}
    for i, v in ipairs(args) do 
        argList[#argList + 1] = parseValue(v, 0, false, 0) 
        argListPretty[#argListPretty + 1] = parseValue(v, 0, true, 0)
    end
    
    local finalArgsStr = table.concat(argList, ", ")
    local finalArgsStrPretty = table.concat(argListPretty, ",\n")
    
    local alreadyExists = false
    for _, m in ipairs(MainMemory) do
        if m.path == eventPath and m.isSelf == isSelf then
            if isSelf then
                if (selfMode and true) or (not selfMode and m.argsStr == finalArgsStr) then
                    alreadyExists = true; break
                end
            else
                if controlMode then alreadyExists = true; break
                else if m.argsStr == finalArgsStr then alreadyExists = true; break end end
            end
        end
    end

    if alreadyExists then return end

    local methodName = (typeLabel == "IS" and "InvokeServer" or (typeLabel == "FC" and "FireClient" or "FireServer"))
    local displayArgs = (finalArgsStr == "" and "None" or finalArgsStr)
    local displayArgsPretty = (finalArgsStrPretty == "" and "None" or "\n" .. finalArgsStrPretty)

    local logDetails = string.format("Type: %s\n\nPath: %s\n\nArgs: %s\n\nScript:\n%s:%s(%s)", typeLabel, eventPath, displayArgs, eventPath, methodName, finalArgsStr)
    local logDetailsPretty = string.format("Type: %s\n\nPath: %s\n\nArgs: %s\n\nScript:\n%s:%s(%s)", typeLabel, eventPath, displayArgsPretty, eventPath, methodName, finalArgsStr)

    -- ANTI-SPAM
    if not isSelf and not controlMode and antiSpam then
        if (tick() - (AntiSpamCooldowns[eventPath] or 0)) < 0.4 then
            AntiSpamCounts[eventPath] = (AntiSpamCounts[eventPath] or 0) + 1
            if AntiSpamCounts[eventPath] >= 4 then
                ManualBannedPaths[eventPath] = {
                    guid = generateGUID(), 
                    details = "AUTO-BANNED BY ANTI-SPAM\n\n" .. logDetails,
                    detailsPretty = "AUTO-BANNED BY ANTI-SPAM\n\n" .. logDetailsPretty
                }
                local nM = {}
                for _, m in ipairs(MainMemory) do 
                    if not (m.path == eventPath and not m.isSelf) then nM[#nM + 1] = m end 
                end
                MainMemory = nM; lastCount = -1; currentSelectionGUID = nil; updateRedListUI(); return 
            end
        else AntiSpamCounts[eventPath] = 0 end
        AntiSpamCooldowns[eventPath] = tick()
    end

    local data = { 
        guid = generateGUID(), name = tostring(rem.Name), type = typeLabel, isSelf = isSelf, 
        fullText = logDetails, fullTextPretty = logDetailsPretty, path = eventPath, argsStr = finalArgsStr 
    }
    
    for i = #MainMemory, 1, -1 do MainMemory[i + 1] = MainMemory[i] end
    MainMemory[1] = data
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

-- INTERACTIONS
ControlBtn.MouseButton1Click:Connect(function() 
    controlMode = not controlMode
    ControlBtn.Text = "CONTROL: "..(controlMode and "ON" or "OFF")
    ControlBtn.BackgroundColor3 = controlMode and Color3.fromRGB(0, 170, 190) or Color3.fromRGB(80, 80, 85)
    AntiSpamBtn.Visible = not controlMode; BlockBtn.Visible = not controlMode
    lastCount = -1 
end)

DelBtn.MouseButton1Click:Connect(function()
    if currentSelectionGUID then
        local targetData = nil
        local foundInBanList = false
        for path, data in pairs(ManualBannedPaths) do
            if data.guid == currentSelectionGUID then
                targetData = {path = path, guid = data.guid, isBanList = true}
                foundInBanList = true; break
            end
        end
        if not foundInBanList then
            local nM = {}
            for _, m in ipairs(MainMemory) do
                if m.guid == currentSelectionGUID then targetData = m else nM[#nM+1] = m end
            end
            if targetData then MainMemory = nM end
        end
        if targetData then
            if foundInBanList then
                ManualBannedPaths[targetData.path] = nil
                updateRedListUI(); feedback(DelBtn, "UNBANNED")
            else feedback(DelBtn, "DELETED") end
            lastCount = -1; currentSelectionGUID = nil; Details.Text = ""
        end
    end
end)

BlockBtn.MouseButton1Click:Connect(function()
    if currentSelectionGUID then
        for i, d in ipairs(MainMemory) do
            if d.guid == currentSelectionGUID and not d.isSelf then
                local p = d.path
                if p then
                    ManualBannedPaths[p] = {
                        guid = d.guid, 
                        details = "MANUAL BANNED:\n\n" .. d.fullText,
                        detailsPretty = "MANUAL BANNED:\n\n" .. d.fullTextPretty
                    }
                    local nM = {}
                    for _, m in ipairs(MainMemory) do 
                        if not (m.path == p and not m.isSelf) then nM[#nM+1] = m end 
                    end
                    MainMemory = nM; lastCount = -1; currentSelectionGUID = nil; updateRedListUI(); Details.Text = "Banned."
                    feedback(BlockBtn, "BANNED")
                end; break
            end
        end
    end
end)

MinBtn.MouseButton1Click:Connect(function()
    isMin = not isMin
    local curX, curY = Main.AbsolutePosition.X + Main.AbsoluteSize.X, Main.AbsolutePosition.Y
    if isMin then
        ContentFrame.Visible = false; ControlBtn.Visible = false; SelfBtn.Visible = false; AntiSpamBtn.Visible = false; BlockBtn.Visible = false; DelBtn.Visible = false
        Main:TweenSizeAndPosition(UDim2.new(0, 250, 0, 35), UDim2.new(0, curX - 250, 0, curY), "Out", "Quad", 0.15, true); MinBtn.Text = "+"
    else
        Main:TweenSizeAndPosition(UDim2.new(0, 820, 0, 440), UDim2.new(0, curX - 820, 0, curY), "Out", "Quad", 0.15, true, function()
            ContentFrame.Visible = true; ControlBtn.Visible = true; SelfBtn.Visible = true; DelBtn.Visible = true; if not controlMode then AntiSpamBtn.Visible = true; BlockBtn.Visible = true end
        end); MinBtn.Text = "_"; lastCount = -1
    end
end)

-- RENDER LOOP
task.spawn(function()
    while task.wait(0.5) do
        if not ContentFrame or not ContentFrame.Visible or #MainMemory == lastCount then continue end
        lastCount = #MainMemory; for _, v in pairs(Scroll:GetChildren()) do if v:IsA("TextButton") then v:Destroy() end end
        
        local sortedMemory = {}
        for _, d in ipairs(MainMemory) do if d.isSelf then sortedMemory[#sortedMemory + 1] = d end end
        for _, d in ipairs(MainMemory) do if not d.isSelf then sortedMemory[#sortedMemory + 1] = d end end

        for i, d in ipairs(sortedMemory) do
            local b = Instance.new("TextButton", Scroll); b.Size = UDim2.new(1, -6, 0, 30); b.LayoutOrder = i
            b.Text = string.format("[%s]%s %s", d.type, (d.isSelf and " [S]" or ""), d.name)
            b:SetAttribute("GUID", d.guid); b:SetAttribute("IsSelf", d.isSelf)
            b.BackgroundColor3 = (currentSelectionGUID == d.guid) and Color3.fromRGB(100, 50, 200) or (d.isSelf and Color3.fromRGB(45, 90, 45) or Color3.fromRGB(40, 40, 45))
            b.TextColor3 = Color3.new(1,1,1); b.BorderSizePixel = 0; b.Font = Enum.Font.SourceSansBold; b.TextSize = 12
            b.MouseButton1Click:Connect(function()
                currentSelectionGUID = d.guid; updateDetailsView(); refreshSelectionColors()
            end)
        end
    end
end)

local function createBotBtn(text, pos, size, color)
    local b = Instance.new("TextButton", ContentFrame); b.Size = size or UDim2.new(0, 220, 0, 58); b.Position = pos; b.BackgroundColor3 = color; b.Text = text; b.TextColor3 = Color3.new(1,1,1); b.Font = Enum.Font.SourceSansBold; b.TextSize = 14; b.BorderSizePixel = 0; return b
end

-- Нижние кнопки
local CopyArgsBtn = createBotBtn("COPY ARGS", UDim2.new(0, 205, 0.68, 0), UDim2.new(0, 108, 0, 58), Color3.fromRGB(45, 90, 45))
CopyArgsBtn.MouseButton1Click:Connect(function() 
    local a = Details.Text:match("Args:?%s*(.-)\n\nScript"); 
    if a then setclipboard(a); feedback(CopyArgsBtn, "ARGS COPIED!") end
end)

local SortArgsBtn = createBotBtn("SORT: OFF", UDim2.new(0, 317, 0.68, 0), UDim2.new(0, 108, 0, 58), Color3.fromRGB(80, 80, 85))
SortArgsBtn.MouseButton1Click:Connect(function()
    sortArgs = not sortArgs
    SortArgsBtn.Text = "SORT: " .. (sortArgs and "ON" or "OFF")
    SortArgsBtn.BackgroundColor3 = sortArgs and Color3.fromRGB(0, 170, 190) or Color3.fromRGB(80, 80, 85)
    updateDetailsView()
end)

local CopyScriptBtn = createBotBtn("COPY SCRIPT", UDim2.new(0, 205, 0.83, 0), nil, Color3.fromRGB(60, 60, 120))
CopyScriptBtn.MouseButton1Click:Connect(function() 
    local s = Details.Text:match("Script:\n(.*)"); 
    if s then setclipboard(s); feedback(CopyScriptBtn, "SCRIPT COPIED!") end
end)

local ClearLogBtn = createBotBtn("CLEAR LOG", UDim2.new(0, 432, 0.68, 0), UDim2.new(0, 108, 0, 58), Color3.fromRGB(80, 80, 85))
ClearLogBtn.MouseButton1Click:Connect(function()
    local nM = {}
    for _, m in ipairs(MainMemory) do if m.isSelf then nM[#nM+1] = m end end
    MainMemory = nM; lastCount = -1; feedback(ClearLogBtn, "CLEARED SRV")
end)

local ClearSelfBtn = createBotBtn("CLEAR SELF", UDim2.new(0, 544, 0.68, 0), UDim2.new(0, 108, 0, 58), Color3.fromRGB(100, 80, 60))
ClearSelfBtn.MouseButton1Click:Connect(function()
    local nM = {}
    for _, m in ipairs(MainMemory) do if not m.isSelf then nM[#nM+1] = m end end
    MainMemory = nM; lastCount = -1; feedback(ClearSelfBtn, "CLEARED SELF")
end)

local ExecuteBtn = createBotBtn("EXECUTE", UDim2.new(0, 432, 0.83, 0), nil, Color3.fromRGB(120, 60, 60))
ExecuteBtn.MouseButton1Click:Connect(function() 
    local s = Details.Text:match("Script:\n(.*)") or Details.Text
    if s and s ~= "" then 
        local f = loadstring(s); 
        if f then task.spawn(f); feedback(ExecuteBtn, "EXECUTED!") end 
    end 
end)

SelfBtn.MouseButton1Click:Connect(function() 
    selfMode = not selfMode; lastCount = -1
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
        local ns = (varName == "FS" and spyFS or varName == "FC" and spyFC or spyIS)
        b.Text = varName.." SPY: "..(ns and "ON" or "OFF"); b.BackgroundColor3 = ns and color or Color3.fromRGB(40, 40, 45)
    end)
end
createTypeBtn("FS SPY: ON", UDim2.new(0, 662, 0, 8), spyFS, Color3.fromRGB(130, 70, 220), "FS")
createTypeBtn("FC SPY: OFF", UDim2.new(0, 662, 0, 48), spyFC, Color3.fromRGB(50, 150, 255), "FC")
createTypeBtn("IS SPY: OFF", UDim2.new(0, 662, 0, 88), spyIS, Color3.fromRGB(255, 150, 50), "IS")
