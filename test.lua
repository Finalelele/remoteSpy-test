-- [[ KRALLDEN SPY v9.7.9 FULL SOURCE RESTORED ]] --

local player = game:GetService("Players").LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local TextService = game:GetService("TextService")

-- Очистка старых версий
if playerGui:FindFirstChild("KralldenSpyUI") then 
    playerGui.KralldenSpyUI:Destroy() 
end

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
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "KralldenSpyUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 10
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = targetParent

-- Anti-Hide
task.spawn(function()
    while task.wait(1) do 
        if ScreenGui and ScreenGui.Parent and not ScreenGui.Enabled then 
            ScreenGui.Enabled = true 
        end 
    end
end)

local Main = Instance.new("Frame")
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
Main.Size = UDim2.new(0, 820, 0, 440)
Main.Position = UDim2.new(0.5, -410, 0.5, -220)
Main.Active = true
Main.Draggable = true
Main.BorderSizePixel = 0
Main.Parent = ScreenGui

-- Основные переменные и таблицы
local MainMemory = {}
local PathFilter = {}
local ManualBannedPaths = {}
local AntiSpamCooldowns = {}
local AntiSpamCounts = {}

local selfMode = true
local controlMode = true
local antiSpam = true

local spyFS = true
local spyFC = false
local spyIS = false

local sortEnabled = false
local currentSelectionGUID = nil
local lastCount = 0
local isMin = false

local function generateGUID() 
    return tostring(tick()) .. "-" .. tostring(math.random(1, 100000)) 
end

local RedListScroll
local Scroll
local Details
local ContentFrame
local DetailsScroll

-- Вспомогательные функции UI
local activeFeedbacks = {}
local function feedback(button, tempText)
    if not button or activeFeedbacks[button] then 
        return 
    end
    
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

local function updateDetailsCanvas()
    if DetailsScroll and Details then
        task.defer(function()
            DetailsScroll.CanvasSize = UDim2.new(0, 0, 0, Details.TextBounds.Y + 40)
        end)
    end
end

local function refreshSelectionColors()
    if not Scroll or not RedListScroll then 
        return 
    end
    
    for _, v in pairs(Scroll:GetChildren()) do
        if v:IsA("TextButton") then
            local isSelected = (v:GetAttribute("GUID") == currentSelectionGUID)
            if isSelected then
                v.BackgroundColor3 = Color3.fromRGB(100, 50, 200)
            else
                if v:GetAttribute("IsSelf") then
                    v.BackgroundColor3 = Color3.fromRGB(45, 90, 45)
                else
                    v.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
                end
            end
        end
    end
    
    for _, v in pairs(RedListScroll:GetChildren()) do
        if v:IsA("TextButton") then
            local isSelected = (v:GetAttribute("GUID") == currentSelectionGUID)
            if isSelected then
                v.BackgroundColor3 = Color3.fromRGB(100, 50, 200)
            else
                v.BackgroundColor3 = Color3.fromRGB(100, 35, 35)
            end
        end
    end
end

-- Форматирование данных
local function formatTableVisual(val, indent)
    indent = indent or 0
    local tab = string.rep("    ", indent)
    local t = typeof(val)
    
    if t == "table" then
        local res = "{\n"
        local isArray = true
        local count = 0
        
        for k, v in pairs(val) do 
            count = count + 1
            if type(k) ~= "number" or k ~= count then 
                isArray = false 
                break 
            end 
        end
        
        for k, v in pairs(val) do
            local keyStr = ""
            if not isArray then
                if type(k) == "string" then
                    keyStr = k .. " = "
                else
                    keyStr = "[" .. tostring(k) .. "] = "
                end
            end
            res = res .. tab .. "    " .. keyStr .. formatTableVisual(v, indent + 1) .. ",\n"
        end
        return res .. tab .. "}"
    elseif t == "string" then 
        return '"' .. val .. '"'
    elseif t == "Vector3" then 
        return string.format("Vector3.new(%.3f, %.3f, %.3f)", val.X, val.Y, val.Z)
    elseif t == "CFrame" then 
        return "CFrame.new(" .. tostring(val) .. ")"
    else 
        return tostring(val) 
    end
end

local function getSortedDetails(d)
    local prefix = d.prefix or ""
    if not sortEnabled then 
        return prefix .. d.fullText 
    end
    
    local displayArgs = formatTableVisual(d.rawArgs)
    local methodName = ""
    if d.type == "IS" then
        methodName = "InvokeServer"
    elseif d.type == "FC" then
        methodName = "FireClient"
    else
        methodName = "FireServer"
    end
    
    return prefix .. string.format("Type: %s\n\nPath: %s\n\nArgs: %s\n\nScript:\n%s:%s(%s)", d.type, d.path, displayArgs, d.path, methodName, d.argsStr)
end

-- Логика Бан-листа (UI)
local function updateRedListUI()
    if not RedListScroll then 
        return 
    end
    
    for _, v in pairs(RedListScroll:GetChildren()) do 
        if v:IsA("TextButton") then 
            v:Destroy() 
        end 
    end
    
    for path, data in pairs(ManualBannedPaths) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -6, 0, 25)
        
        if currentSelectionGUID == data.guid then
            b.BackgroundColor3 = Color3.fromRGB(100, 50, 200)
        else
            b.BackgroundColor3 = Color3.fromRGB(100, 35, 35)
        end
        
        b.TextColor3 = Color3.new(1, 1, 1)
        b.Font = Enum.Font.SourceSansBold
        b.TextSize = 10
        b.BorderSizePixel = 0
        b.ClipsDescendants = true
        
        local displayPath = path:match("[^%.%[%]]+$") or path
        b.Text = " [X] " .. displayPath
        b.Parent = RedListScroll
        
        b:SetAttribute("GUID", data.guid)
        b:SetAttribute("Path", path)
        
        b.MouseButton1Click:Connect(function() 
            currentSelectionGUID = data.guid
            Details.Text = getSortedDetails(data) 
            updateDetailsCanvas()
            refreshSelectionColors()
        end)
    end
end

-- ================= HEADER =================
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 35)
Header.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
Header.ZIndex = 10
Header.BorderSizePixel = 0
Header.Parent = Main

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(0, 200, 1, 0)
Title.BackgroundTransparency = 1
Title.Position = UDim2.new(0, 15, 0, 0)
Title.Text = "KRALLDEN SPY v9.7.9"
Title.TextColor3 = Color3.new(1, 1, 1)
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 16
Title.ZIndex = 11
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 45, 0, 35)
MinBtn.Position = UDim2.new(1, -45, 0, 0)
MinBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 180)
MinBtn.Text = "_"
MinBtn.TextColor3 = Color3.new(1, 1, 1)
MinBtn.TextSize = 22
MinBtn.ZIndex = 12
MinBtn.BorderSizePixel = 0
MinBtn.Parent = Header

local function createHeaderBtn(text, offset, color, sizeX)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, sizeX or 100, 0, 24)
    b.Position = UDim2.new(1, offset, 0.5, -12)
    b.BackgroundColor3 = color
    b.Text = text
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.SourceSansBold
    b.TextSize = 11
    b.ZIndex = 11
    b.BorderSizePixel = 0
    b.Parent = Header
    return b
end

local ControlBtn = createHeaderBtn("CONTROL: ON", -150, Color3.fromRGB(0, 170, 190))
local SelfBtn = createHeaderBtn("SELF: ON", -235, Color3.fromRGB(45, 90, 45), 80)
local DelBtn = createHeaderBtn("DEL BTN", -310, Color3.fromRGB(200, 100, 0), 70)
local AntiSpamBtn = createHeaderBtn("ANTI-SPAM: ON", -420, Color3.fromRGB(180, 150, 40))
AntiSpamBtn.Visible = false
local BlockBtn = createHeaderBtn("BLOCK EVENT", -530, Color3.fromRGB(150, 50, 50))
BlockBtn.Visible = false

-- ================= CONTENT =================
ContentFrame = Instance.new("Frame")
ContentFrame.Name = "ContentFrame"
ContentFrame.Size = UDim2.new(1, 0, 1, -35)
ContentFrame.Position = UDim2.new(0, 0, 0, 35)
ContentFrame.BackgroundTransparency = 1
ContentFrame.ClipsDescendants = true
ContentFrame.Parent = Main

Scroll = Instance.new("ScrollingFrame")
Scroll.Position = UDim2.new(0, 8, 0, 8)
Scroll.Size = UDim2.new(0, 190, 1, -16)
Scroll.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 4
Scroll.Parent = ContentFrame

local ScrollLayout = Instance.new("UIListLayout")
ScrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
ScrollLayout.Parent = Scroll

DetailsScroll = Instance.new("ScrollingFrame")
DetailsScroll.Position = UDim2.new(0, 205, 0, 8)
DetailsScroll.Size = UDim2.new(0, 448, 0, 255)
DetailsScroll.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
DetailsScroll.BorderSizePixel = 0
DetailsScroll.ScrollBarThickness = 4
DetailsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
DetailsScroll.Parent = ContentFrame

Details = Instance.new("TextBox")
Details.Size = UDim2.new(1, -10, 0, 0)
Details.Position = UDim2.new(0, 5, 0, 5)
Details.BackgroundTransparency = 1
Details.TextColor3 = Color3.new(1, 1, 1)
Details.MultiLine = true
Details.TextWrapped = true
Details.TextEditable = true
Details.Font = Enum.Font.Code
Details.TextSize = 12
Details.TextXAlignment = Enum.TextXAlignment.Left
Details.TextYAlignment = Enum.TextYAlignment.Top
Details.ClearTextOnFocus = false
Details.AutomaticSize = Enum.AutomaticSize.Y
Details.Parent = DetailsScroll

Details:GetPropertyChangedSignal("Text"):Connect(updateDetailsCanvas)

local BanListTitle = Instance.new("TextLabel")
BanListTitle.Size = UDim2.new(0, 150, 0, 20)
BanListTitle.Position = UDim2.new(0, 662, 0, 125)
BanListTitle.BackgroundTransparency = 1
BanListTitle.Text = "BAN LIST"
BanListTitle.TextColor3 = Color3.fromRGB(255, 100, 100)
BanListTitle.Font = Enum.Font.SourceSansBold
BanListTitle.TextSize = 14
BanListTitle.Parent = ContentFrame

RedListScroll = Instance.new("ScrollingFrame")
RedListScroll.Position = UDim2.new(0, 662, 0, 145)
RedListScroll.Size = UDim2.new(0, 150, 0, 250)
RedListScroll.BackgroundColor3 = Color3.fromRGB(30, 15, 15)
RedListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
RedListScroll.BorderSizePixel = 0
RedListScroll.ScrollBarThickness = 4
RedListScroll.Parent = ContentFrame

local RedListLayout = Instance.new("UIListLayout")
RedListLayout.SortOrder = Enum.SortOrder.LayoutOrder
RedListLayout.Parent = RedListScroll

-- ================= PATH LOGIC =================
local function getSafePath(obj)
    local p = ""
    pcall(function() 
        local t = obj
        while t and t ~= game do 
            local n = tostring(t.Name)
            local safeName = ""
            if n:match("^%d") or n:match("[%s%W]") then
                safeName = '["' .. n .. '"]'
            else
                safeName = n
            end
            
            if p == "" then 
                p = safeName 
            else 
                if safeName:sub(1,1) == "[" then
                    p = safeName .. "." .. p 
                else
                    p = safeName .. "." .. p
                end
            end
            t = t.Parent 
        end 
    end)
    
    local finalPath = "game." .. p
    return finalPath:gsub("%.%[", "[") 
end

-- ================= ADD LOG =================
local function addLog(rem, args, isSelf, typeLabel)
    if typeLabel == "FS" and not spyFS then return end
    if typeLabel == "FC" and not spyFC then return end
    if typeLabel == "IS" and not spyIS then return end
    
    local eventPath = getSafePath(rem)
    
    if not isSelf and ManualBannedPaths[eventPath] then 
        return 
    end

    local function parseValue(v, d)
        d = d or 0
        if d > 4 then return "..." end
        
        local t = type(v)
        if t == "string" then 
            return '"' .. v .. '"'
        elseif t == "table" then
            local isArray = true
            local count = 0
            for k, val in pairs(v) do 
                count = count + 1
                if type(k) ~= "number" or k ~= count then 
                    isArray = false 
                    break 
                end 
            end
            
            local res = "{"
            local i = 0
            for k, val in pairs(v) do 
                i = i + 1
                if i > 15 then 
                    res = res .. "... " 
                    break 
                end
                
                if isArray then 
                    res = res .. parseValue(val, d + 1) .. ", " 
                else 
                    local key = (type(k) == "number") and "["..k.."]" or '["'..tostring(k)..'"]'
                    res = res .. key .. " = " .. parseValue(val, d + 1) .. ", " 
                end
            end
            
            local result = res:gsub(", $", "") .. "}"
            return (result == "}") and "{}" or result
        elseif t == "userdata" then
            local tn = typeof(v)
            if tn == "CFrame" then return "CFrame.new(" .. tostring(v) .. ")"
            elseif tn == "Vector3" then return "Vector3.new(" .. tostring(v) .. ")"
            elseif tn == "Instance" then return getSafePath(v) end
            return tostring(v)
        else 
            return tostring(v) 
        end
    end

    local argList = {}
    for i, v in ipairs(args) do 
        -- Замена table.insert на индексы
        argList[#argList + 1] = parseValue(v)
    end
    
    local finalArgsStr = table.concat(argList, ", ")
    
    local alreadyExists = false
    for _, m in ipairs(MainMemory) do
        if m.path == eventPath and m.isSelf == isSelf then
            if isSelf then 
                if selfMode or m.argsStr == finalArgsStr then 
                    alreadyExists = true
                    break 
                end
            else 
                if controlMode or m.argsStr == finalArgsStr then 
                    alreadyExists = true
                    break 
                end 
            end
        end
    end
    
    if alreadyExists then 
        return 
    end

    local methodName = (typeLabel == "IS") and "InvokeServer" or (typeLabel == "FC" and "FireClient" or "FireServer")
    local displayArgs = (finalArgsStr == "") and "None" or finalArgsStr
    
    local logDetails = string.format(
        "Type: %s\n\nPath: %s\n\nArgs: %s\n\nScript:\n%s:%s(%s)", 
        typeLabel, eventPath, displayArgs, eventPath, methodName, finalArgsStr
    )

    -- Anti-Spam Logic
    if not isSelf and not controlMode and antiSpam then
        local currentTime = tick()
        if (currentTime - (AntiSpamCooldowns[eventPath] or 0)) < 0.4 then
            AntiSpamCounts[eventPath] = (AntiSpamCounts[eventPath] or 0) + 1
            if AntiSpamCounts[eventPath] >= 4 then
                ManualBannedPaths[eventPath] = {
                    guid = generateGUID(), 
                    prefix = "AUTO-BANNED\n\n", 
                    fullText = logDetails, 
                    rawArgs = args, 
                    type = typeLabel, 
                    path = eventPath, 
                    argsStr = finalArgsStr
                }
                
                local nM = {}
                for _, m in ipairs(MainMemory) do 
                    if not (m.path == eventPath and not m.isSelf) then 
                        -- Замена table.insert на индексы
                        nM[#nM + 1] = m 
                    end 
                end
                
                MainMemory = nM
                lastCount = -1
                currentSelectionGUID = nil
                updateRedListUI()
                return 
            end
        else 
            AntiSpamCounts[eventPath] = 0 
        end
        AntiSpamCooldowns[eventPath] = currentTime
    end

    -- Добавление в память
    local newLog = { 
        guid = generateGUID(), 
        name = tostring(rem.Name), 
        type = typeLabel, 
        isSelf = isSelf, 
        fullText = logDetails, 
        path = eventPath, 
        argsStr = finalArgsStr, 
        rawArgs = args 
    }
    
    -- Кастомная вставка в начало таблицы без table.insert
    for idx = #MainMemory, 1, -1 do
        MainMemory[idx + 1] = MainMemory[idx]
    end
    MainMemory[1] = newLog
    
    -- Замена table.remove(MainMemory, #MainMemory)
    if #MainMemory > 150 then 
        MainMemory[#MainMemory] = nil 
    end
end

-- ================= ПЕРЕХВАТ (HOOKS) =================
local mt = getrawmetatable(game)
local old = mt.__namecall
setreadonly(mt, false)

mt.__namecall = newcclosure(function(self, ...)
    local m = getnamecallmethod()
    local a = {...}
    local s = checkcaller()
    
    local lowerM = m:lower()
    if lowerM == "fireserver" then 
        task.spawn(addLog, self, a, s, "FS")
    elseif lowerM == "fireclient" then 
        task.spawn(addLog, self, a, s, "FC")
    elseif lowerM == "invokeserver" then 
        task.spawn(addLog, self, a, s, "IS") 
    end
    
    return old(self, ...)
end)
setreadonly(mt, true)

-- ================= INTERACTIONS =================
ControlBtn.MouseButton1Click:Connect(function() 
    controlMode = not controlMode
    if controlMode then
        ControlBtn.Text = "CONTROL: ON"
        ControlBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 190)
        AntiSpamBtn.Visible = false
        BlockBtn.Visible = false
    else
        ControlBtn.Text = "CONTROL: OFF"
        ControlBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 85)
        AntiSpamBtn.Visible = true
        BlockBtn.Visible = true
    end
    lastCount = -1 
end)

DelBtn.MouseButton1Click:Connect(function()
    if currentSelectionGUID then
        local targetData = nil
        local foundInBanList = false
        
        for path, data in pairs(ManualBannedPaths) do
            if data.guid == currentSelectionGUID then 
                targetData = {path = path, guid = data.guid}
                foundInBanList = true
                break 
            end
        end
        
        if not foundInBanList then
            local nM = {}
            for _, m in ipairs(MainMemory) do 
                if m.guid == currentSelectionGUID then 
                    targetData = m 
                else 
                    -- Замена table.insert на индексы
                    nM[#nM + 1] = m 
                end 
            end
            if targetData then MainMemory = nM end
        end
        
        if targetData then
            if foundInBanList then 
                ManualBannedPaths[targetData.path] = nil
                updateRedListUI()
                feedback(DelBtn, "UNBANNED") 
            else 
                feedback(DelBtn, "DELETED") 
            end
            
            lastCount = -1
            currentSelectionGUID = nil
            Details.Text = ""
            updateDetailsCanvas()
        end
    end
end)

BlockBtn.MouseButton1Click:Connect(function()
    if currentSelectionGUID then
        for i, d in ipairs(MainMemory) do
            if d.guid == currentSelectionGUID and not d.isSelf then
                ManualBannedPaths[d.path] = {
                    guid = d.guid, 
                    prefix = "MANUAL BANNED:\n\n", 
                    fullText = d.fullText, 
                    rawArgs = d.rawArgs, 
                    type = d.type, 
                    path = d.path, 
                    argsStr = d.argsStr
                }
                
                local nM = {}
                for _, m in ipairs(MainMemory) do 
                    if not (m.path == d.path and not m.isSelf) then 
                        -- Замена table.insert на индексы
                        nM[#nM + 1] = m 
                    end 
                end
                
                MainMemory = nM
                lastCount = -1
                currentSelectionGUID = nil
                updateRedListUI()
                Details.Text = "Banned."
                updateDetailsCanvas()
                feedback(BlockBtn, "BANNED")
                break
            end
        end
    end
end)

MinBtn.MouseButton1Click:Connect(function()
    isMin = not isMin
    local curX = Main.AbsolutePosition.X + Main.AbsoluteSize.X
    local curY = Main.AbsolutePosition.Y
    
    if isMin then
        ContentFrame.Visible = false
        ControlBtn.Visible = false
        SelfBtn.Visible = false
        AntiSpamBtn.Visible = false
        BlockBtn.Visible = false
        DelBtn.Visible = false
        
        Main:TweenSizeAndPosition(UDim2.new(0, 250, 0, 35), UDim2.new(0, curX - 250, 0, curY), "Out", "Quad", 0.15, true)
        MinBtn.Text = "+"
    else
        Main:TweenSizeAndPosition(UDim2.new(0, 820, 0, 440), UDim2.new(0, curX - 820, 0, curY), "Out", "Quad", 0.15, true, function()
            ContentFrame.Visible = true
            ControlBtn.Visible = true
            SelfBtn.Visible = true
            DelBtn.Visible = true
            if not controlMode then
                AntiSpamBtn.Visible = true
                BlockBtn.Visible = true
            end
        end)
        MinBtn.Text = "_"
        lastCount = -1
    end
end)

-- ================= RENDER LOOP =================
task.spawn(function()
    while task.wait(0.5) do
        if not ContentFrame or not ContentFrame.Visible then continue end
        if #MainMemory == lastCount then continue end
        
        lastCount = #MainMemory
        for _, v in pairs(Scroll:GetChildren()) do 
            if v:IsA("TextButton") then v:Destroy() end 
        end
        
        local sortedMemory = {}
        for _, d in ipairs(MainMemory) do 
            if d.isSelf then 
                -- Замена table.insert на индексы
                sortedMemory[#sortedMemory + 1] = d 
            end 
        end
        for _, d in ipairs(MainMemory) do 
            if not d.isSelf then 
                -- Замена table.insert на индексы
                sortedMemory[#sortedMemory + 1] = d 
            end 
        end
        
        for i, d in ipairs(sortedMemory) do
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(1, -6, 0, 30)
            b.LayoutOrder = i
            
            local display = string.format("[%s]%s %s", d.type, (d.isSelf and " [S]" or ""), d.name)
            b.Text = display
            
            if currentSelectionGUID == d.guid then
                b.BackgroundColor3 = Color3.fromRGB(100, 50, 200)
            else
                if d.isSelf then
                    b.BackgroundColor3 = Color3.fromRGB(45, 90, 45)
                else
                    b.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
                end
            end
            
            b.TextColor3 = Color3.new(1, 1, 1)
            b.BorderSizePixel = 0
            b.ClipsDescendants = true
            b.Parent = Scroll
            
            b:SetAttribute("GUID", d.guid)
            b:SetAttribute("IsSelf", d.isSelf)
            
            b.MouseButton1Click:Connect(function()
                currentSelectionGUID = d.guid
                Details.Text = getSortedDetails(d)
                updateDetailsCanvas()
                refreshSelectionColors()
            end)
        end
    end
end)

-- ================= BOTTOM BUTTONS =================
local function createBotBtn(text, pos, size, color)
    local b = Instance.new("TextButton")
    b.Size = size or UDim2.new(0, 220, 0, 58)
    b.Position = pos
    b.BackgroundColor3 = color
    b.Text = text
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.SourceSansBold
    b.TextSize = 14
    b.BorderSizePixel = 0
    b.Parent = ContentFrame
    return b
end

local CopyArgsBtn = createBotBtn("COPY ARGS", UDim2.new(0, 205, 0.68, 0), UDim2.new(0, 95, 0, 58), Color3.fromRGB(45, 90, 45))
CopyArgsBtn.MouseButton1Click:Connect(function() 
    local a = Details.Text:match("Args: (.-)\n\nScript")
    if a then 
        setclipboard(a) 
        feedback(CopyArgsBtn, "COPIED!")
    end
end)

local SortBtn = createBotBtn("SORT: OFF", UDim2.new(0, 305, 0.68, 0), UDim2.new(0, 120, 0, 58), Color3.fromRGB(80, 80, 85))
SortBtn.MouseButton1Click:Connect(function()
    sortEnabled = not sortEnabled
    if sortEnabled then
        SortBtn.Text = "SORT: ON"
        SortBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 140)
    else
        SortBtn.Text = "SORT: OFF"
        SortBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 85)
    end
    
    if currentSelectionGUID then
        local found = false
        for _, m in ipairs(MainMemory) do
            if m.guid == currentSelectionGUID then
                Details.Text = getSortedDetails(m)
                found = true
                break
            end
        end
        if not found then
            for _, d in pairs(ManualBannedPaths) do
                if d.guid == currentSelectionGUID then
                    Details.Text = getSortedDetails(d)
                    break
                end
            end
        end
        updateDetailsCanvas()
    end
end)

local CopyScriptBtn = createBotBtn("COPY SCRIPT", UDim2.new(0, 205, 0.83, 0), nil, Color3.fromRGB(60, 60, 120))
CopyScriptBtn.MouseButton1Click:Connect(function() 
    local s = Details.Text:match("Script:\n(.*)")
    if s then 
        setclipboard(s) 
        feedback(CopyScriptBtn, "COPIED!")
    end
end)

local ClearLogBtn = createBotBtn("CLEAR LOG", UDim2.new(0, 432, 0.68, 0), UDim2.new(0, 108, 0, 58), Color3.fromRGB(80, 80, 85))
ClearLogBtn.MouseButton1Click:Connect(function()
    local nM = {}
    for _, m in ipairs(MainMemory) do 
        if m.isSelf then 
            -- Замена table.insert на индексы
            nM[#nM + 1] = m 
        end 
    end
    MainMemory = nM
    lastCount = -1
    feedback(ClearLogBtn, "CLEARED")
end)

local ClearSelfBtn = createBotBtn("CLEAR SELF", UDim2.new(0, 544, 0.68, 0), UDim2.new(0, 108, 0, 58), Color3.fromRGB(100, 80, 60))
ClearSelfBtn.MouseButton1Click:Connect(function()
    local nM = {}
    for _, m in ipairs(MainMemory) do 
        if not m.isSelf then 
            -- Замена table.insert на индексы
            nM[#nM + 1] = m 
        end 
    end
    MainMemory = nM
    lastCount = -1
    feedback(ClearSelfBtn, "CLEARED")
end)

local ExecuteBtn = createBotBtn("EXECUTE", UDim2.new(0, 432, 0.83, 0), nil, Color3.fromRGB(120, 60, 60))
ExecuteBtn.MouseButton1Click:Connect(function() 
    local s = Details.Text:match("Script:\n(.*)") or Details.Text
    if s and s ~= "" then 
        local f = loadstring(s)
        if f then 
            task.spawn(f) 
            feedback(ExecuteBtn, "EXECUTED!")
        end
    end 
end)

SelfBtn.MouseButton1Click:Connect(function() 
    selfMode = not selfMode
    if selfMode then
        SelfBtn.Text = "SELF: ON"
        SelfBtn.BackgroundColor3 = Color3.fromRGB(45, 90, 45)
    else
        SelfBtn.Text = "SELF: OFF"
        SelfBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
    end
    lastCount = -1
end)

AntiSpamBtn.MouseButton1Click:Connect(function() 
    antiSpam = not antiSpam
    if antiSpam then
        AntiSpamBtn.Text = "ANTI-SPAM: ON"
        AntiSpamBtn.BackgroundColor3 = Color3.fromRGB(180, 150, 40)
    else
        AntiSpamBtn.Text = "ANTI-SPAM: OFF"
        AntiSpamBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 85)
    end
end)

-- ================= ТРИ КНОПКИ (FS, FC, IS) =================
local function createTypeBtn(text, pos, state, color, varName)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 150, 0, 35)
    b.Position = pos
    
    if state then
        b.BackgroundColor3 = color
    else
        b.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    end
    
    b.Text = text
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.SourceSansBold
    b.TextSize = 12
    b.BorderSizePixel = 0
    b.Parent = ContentFrame
    
    b.MouseButton1Click:Connect(function()
        if varName == "FS" then 
            spyFS = not spyFS 
        elseif varName == "FC" then 
            spyFC = not spyFC 
        elseif varName == "IS" then 
            spyIS = not spyIS 
        end

        local currentState = false
        if varName == "FS" then currentState = spyFS
        elseif varName == "FC" then currentState = spyFC
        elseif varName == "IS" then currentState = spyIS end

        b.Text = varName .. " SPY: " .. (currentState and "ON" or "OFF")
        if currentState then
            b.BackgroundColor3 = color
        else
            b.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
        end
    end)
end

createTypeBtn("FS SPY: ON", UDim2.new(0, 662, 0, 8), spyFS, Color3.fromRGB(130, 70, 220), "FS")
createTypeBtn("FC SPY: OFF", UDim2.new(0, 662, 0, 48), spyFC, Color3.fromRGB(50, 150, 255), "FC")
createTypeBtn("IS SPY: OFF", UDim2.new(0, 662, 0, 88), spyIS, Color3.fromRGB(255, 150, 50), "IS")
