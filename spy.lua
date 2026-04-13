-- [[ KRALLDEN SPY v9.4.6 - PERFORMANCE BOOST & ANTI-REMOVAL ]] --

_G.KralldenStorage = _G.KralldenStorage or {
    MainMemory = {},
    ManualBannedPaths = {},
    Settings = {
        selfMode = true,
        controlMode = true,
        antiSpam = true,
        spyFS = true,
        spyFC = false,
        spyIS = false
    }
}

local player = game:GetService("Players").LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local MainMemory = _G.KralldenStorage.MainMemory
local ManualBannedPaths = _G.KralldenStorage.ManualBannedPaths
local Settings = _G.KralldenStorage.Settings
local PathCache = {} -- Кэш для путей (ускоряет работу в десятки раз)

local currentSelectionGUID, lastCount = nil, 0
local isMin = false

local function generateGUID() return tostring(tick()) .. "-" .. tostring(math.random(1, 100000)) end

-- Оптимизированный расчет пути
local function getSafePath(obj)
    if PathCache[obj] then return PathCache[obj] end
    local p = ""
    local ok = pcall(function() 
        local t = obj
        while t and t ~= game do 
            local n = tostring(t.Name)
            local safeName = (n:match("^%d") or n:match("[%s%W]")) and '["'..n..'"]' or n
            p = (p == "" and safeName or safeName .. "." .. p)
            t = t.Parent 
        end 
    end)
    local finalPath = "game." .. p:gsub("%.%[", "[")
    PathCache[obj] = finalPath
    return finalPath
end

local function CreateSpyUI()
    if playerGui:FindFirstChild("KralldenSpyUI") then playerGui.KralldenSpyUI:Destroy() end

    local ScreenGui = Instance.new("ScreenGui", playerGui)
    ScreenGui.Name = "KralldenSpyUI"; ScreenGui.ResetOnSpawn = false; ScreenGui.DisplayOrder = 2147483647

    local Main = Instance.new("Frame", ScreenGui)
    Main.BackgroundColor3 = Color3.fromRGB(15, 15, 20); Main.Size = UDim2.new(0, 820, 0, 440)
    Main.Position = UDim2.new(0.5, -410, 0.5, -220); Main.Active = true; Main.Draggable = true; Main.BorderSizePixel = 0

    local RedListScroll, Scroll, Details, ContentFrame

    local activeFeedbacks = {}
    local function feedback(button, tempText)
        if activeFeedbacks[button] then return end
        activeFeedbacks[button] = true
        local oldText = button.Text
        button.Text = tempText
        task.delay(1, function() if button and button.Parent then button.Text = oldText; activeFeedbacks[button] = nil end end)
    end

    local function refreshSelectionColors()
        if not Scroll then return end
        for _, v in pairs(Scroll:GetChildren()) do
            if v:IsA("TextButton") then
                local isSelected = (v:GetAttribute("GUID") == currentSelectionGUID)
                v.BackgroundColor3 = isSelected and Color3.fromRGB(100, 50, 200) or (v:GetAttribute("IsSelf") and Color3.fromRGB(45, 90, 45) or Color3.fromRGB(40, 40, 45))
            end
        end
    end

    local function updateRedListUI()
        if not RedListScroll then return end
        for _, v in pairs(RedListScroll:GetChildren()) do if v:IsA("TextButton") then v:Destroy() end end
        for path, data in pairs(ManualBannedPaths) do
            local b = Instance.new("TextButton", RedListScroll)
            b.Size = UDim2.new(1, -6, 0, 25); b:SetAttribute("GUID", data.guid)
            b.BackgroundColor3 = (currentSelectionGUID == data.guid) and Color3.fromRGB(100, 50, 200) or Color3.fromRGB(100, 35, 35)
            b.TextColor3 = Color3.new(1,1,1); b.Font = Enum.Font.SourceSansBold; b.TextSize = 10; b.Text = " [X] " .. (path:match("[^%.%[%]]+$") or path); b.BorderSizePixel = 0
            b.MouseButton1Click:Connect(function() currentSelectionGUID = data.guid; Details.Text = data.details; refreshSelectionColors() end)
        end
    end

    local Header = Instance.new("Frame", Main)
    Header.Size = UDim2.new(1, 0, 0, 35); Header.BackgroundColor3 = Color3.fromRGB(25, 25, 30); Header.BorderSizePixel = 0

    local Title = Instance.new("TextLabel", Header)
    Title.Size = UDim2.new(0, 200, 1, 0); Title.BackgroundTransparency = 1; Title.Position = UDim2.new(0, 15, 0, 0)
    Title.Text = "KRALLDEN SPY v9.4.6 (FAST)"; Title.TextColor3 = Color3.new(1, 1, 1); Title.Font = Enum.Font.SourceSansBold; Title.TextSize = 16; Title.TextXAlignment = 0

    local MinBtn = Instance.new("TextButton", Header)
    MinBtn.Size = UDim2.new(0, 45, 0, 35); MinBtn.Position = UDim2.new(1, -45, 0, 0); MinBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 180); MinBtn.Text = "_"; MinBtn.TextColor3 = Color3.new(1, 1, 1); MinBtn.TextSize = 22; MinBtn.BorderSizePixel = 0

    local function createHeaderBtn(text, offset, color, sizeX)
        local b = Instance.new("TextButton", Header)
        b.Size = UDim2.new(0, sizeX or 100, 0, 24); b.Position = UDim2.new(1, offset, 0.5, -12); b.BackgroundColor3 = color; b.Text = text; b.TextColor3 = Color3.new(1,1,1); b.Font = Enum.Font.SourceSansBold; b.TextSize = 11; b.BorderSizePixel = 0
        return b
    end

    local ControlBtn = createHeaderBtn("CONTROL: "..(Settings.controlMode and "ON" or "OFF"), -150, Settings.controlMode and Color3.fromRGB(0, 170, 190) or Color3.fromRGB(80, 80, 85))
    local SelfBtn = createHeaderBtn("SELF: "..(Settings.selfMode and "ON" or "OFF"), -235, Settings.selfMode and Color3.fromRGB(45, 90, 45) or Color3.fromRGB(150, 50, 50), 80)
    local DelBtn = createHeaderBtn("DEL BTN", -310, Color3.fromRGB(200, 100, 0), 70)
    local AntiSpamBtn = createHeaderBtn("ANTI-SPAM: "..(Settings.antiSpam and "ON" or "OFF"), -420, Settings.antiSpam and Color3.fromRGB(180, 150, 40) or Color3.fromRGB(80, 80, 85))
    AntiSpamBtn.Visible = not Settings.controlMode
    local BlockBtn = createHeaderBtn("BLOCK EVENT", -530, Color3.fromRGB(150, 50, 50))
    BlockBtn.Visible = not Settings.controlMode

    ContentFrame = Instance.new("Frame", Main)
    ContentFrame.Size = UDim2.new(1, 0, 1, -35); ContentFrame.Position = UDim2.new(0, 0, 0, 35); ContentFrame.BackgroundTransparency = 1; ContentFrame.ClipsDescendants = true

    Scroll = Instance.new("ScrollingFrame", ContentFrame)
    Scroll.Position = UDim2.new(0, 8, 0, 8); Scroll.Size = UDim2.new(0, 190, 1, -16); Scroll.BackgroundColor3 = Color3.fromRGB(20, 20, 25); Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; Scroll.BorderSizePixel = 0
    Instance.new("UIListLayout", Scroll).SortOrder = Enum.SortOrder.LayoutOrder

    Details = Instance.new("TextBox", ContentFrame)
    Details.Position = UDim2.new(0, 205, 0, 8); Details.Size = UDim2.new(0, 448, 0, 255); Details.BackgroundColor3 = Color3.fromRGB(10, 10, 12); Details.TextColor3 = Color3.new(1, 1, 1); Details.MultiLine = true; Details.TextWrapped = true; Details.TextEditable = true; Details.Font = Enum.Font.Code; Details.TextSize = 12; Details.TextXAlignment = 0; Details.TextYAlignment = 0; Details.ClearTextOnFocus = false

    RedListScroll = Instance.new("ScrollingFrame", ContentFrame)
    RedListScroll.Position = UDim2.new(0, 662, 0, 145); RedListScroll.Size = UDim2.new(0, 150, 0, 250); RedListScroll.BackgroundColor3 = Color3.fromRGB(30, 15, 15); RedListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; RedListScroll.BorderSizePixel = 0
    Instance.new("UIListLayout", RedListScroll).SortOrder = Enum.SortOrder.LayoutOrder

    updateRedListUI()

    _G.KralldenAddLog = function(rem, args, isSelf, typeLabel)
        if (typeLabel == "FS" and not Settings.spyFS) or (typeLabel == "FC" and not Settings.spyFC) or (typeLabel == "IS" and not Settings.spyIS) then return end
        local eventPath = getSafePath(rem)
        if not isSelf and ManualBannedPaths[eventPath] then return end

        local function parseValue(v, d)
            d = d or 0; if d > 2 then return "..." end
            local t = type(v)
            if t == "string" then return '"' .. v .. '"'
            elseif t == "table" then
                local res, i = "{", 0
                for k, val in pairs(v) do i = i + 1; if i > 5 then res = res .. "... " break end
                    res = res .. (type(k) == "number" and "" or '["'..tostring(k)..'"] = ') .. parseValue(val, d + 1) .. ", "
                end
                return res:gsub(", $", "") .. "}"
            elseif t == "userdata" then return typeof(v) == "Instance" and getSafePath(v) or tostring(v)
            else return tostring(v) end
        end

        local argList = {}
        for i, v in ipairs(args) do argList[i] = parseValue(v) end
        local finalArgsStr = table.concat(argList, ", ")
        
        local alreadyExists = false
        for _, m in ipairs(MainMemory) do
            if m.path == eventPath and m.isSelf == isSelf then
                if isSelf then if Settings.selfMode or m.argsStr == finalArgsStr then alreadyExists = true; break end
                else if Settings.controlMode or m.argsStr == finalArgsStr then alreadyExists = true; break end end
            end
        end
        if alreadyExists then return end

        local methodName = (typeLabel == "IS" and "InvokeServer" or (typeLabel == "FC" and "FireClient" or "FireServer"))
        local logDetails = string.format("Type: %s\nPath: %s\nArgs: %s\n\nScript:\n%s:%s(%s)", typeLabel, eventPath, (finalArgsStr == "" and "None" or finalArgsStr), eventPath, methodName, finalArgsStr)

        local data = { guid = generateGUID(), name = tostring(rem.Name), type = typeLabel, isSelf = isSelf, fullText = logDetails, path = eventPath, argsStr = finalArgsStr }
        table.insert(MainMemory, 1, data)
        if #MainMemory > 100 then table.remove(MainMemory, 101) end -- Лимит памяти
    end

    -- Оптимизированный рендер
    task.spawn(function()
        while task.wait(0.5) do
            if not Main or not Main.Parent or #MainMemory == lastCount then continue end
            lastCount = #MainMemory
            for _, v in pairs(Scroll:GetChildren()) do if v:IsA("TextButton") then v:Destroy() end end
            
            for i, d in ipairs(MainMemory) do
                if i > 50 then break end -- Отрисовываем только первые 50 для скорости
                local b = Instance.new("TextButton", Scroll)
                b.Size = UDim2.new(1, -6, 0, 30); b.Text = string.format("[%s]%s %s", d.type, (d.isSelf and " [S]" or ""), d.name)
                b:SetAttribute("GUID", d.guid); b:SetAttribute("IsSelf", d.isSelf)
                b.BackgroundColor3 = (currentSelectionGUID == d.guid) and Color3.fromRGB(100, 50, 200) or (d.isSelf and Color3.fromRGB(45, 90, 45) or Color3.fromRGB(40, 40, 45))
                b.TextColor3 = Color3.new(1,1,1); b.BorderSizePixel = 0
                b.MouseButton1Click:Connect(function() currentSelectionGUID = d.guid; Details.Text = d.fullText; refreshSelectionColors() end)
            end
        end
    end)

    -- Кнопки управления (Control, Self, Delete, etc.)
    ControlBtn.MouseButton1Click:Connect(function() Settings.controlMode = not Settings.controlMode; ControlBtn.Text = "CONTROL: "..(Settings.controlMode and "ON" or "OFF"); ControlBtn.BackgroundColor3 = Settings.controlMode and Color3.fromRGB(0, 170, 190) or Color3.fromRGB(80, 80, 85); AntiSpamBtn.Visible = not Settings.controlMode; BlockBtn.Visible = not Settings.controlMode; lastCount = -1 end)
    DelBtn.MouseButton1Click:Connect(function() if currentSelectionGUID then for i, m in ipairs(MainMemory) do if m.guid == currentSelectionGUID then table.remove(MainMemory, i); break end end; lastCount = -1; currentSelectionGUID = nil; Details.Text = ""; feedback(DelBtn, "DELETED") end end)
    
    local function createBotBtn(text, pos, size, color)
        local b = Instance.new("TextButton", ContentFrame); b.Size = size or UDim2.new(0, 220, 0, 58); b.Position = pos; b.BackgroundColor3 = color; b.Text = text; b.TextColor3 = Color3.new(1,1,1); b.Font = Enum.Font.SourceSansBold; b.TextSize = 14; b.BorderSizePixel = 0; return b
    end
    createBotBtn("COPY SCRIPT", UDim2.new(0, 205, 0.83, 0), nil, Color3.fromRGB(60, 60, 120)).MouseButton1Click:Connect(function() local s = Details.Text:match("Script:\n(.*)"); if s then setclipboard(s) end end)
    createBotBtn("CLEAR LOG", UDim2.new(0, 432, 0.68, 0), UDim2.new(0, 108, 0, 58), Color3.fromRGB(80, 80, 85)).MouseButton1Click:Connect(function() for i=#MainMemory,1,-1 do if not MainMemory[i].isSelf then table.remove(MainMemory, i) end end; lastCount = -1 end)

    MinBtn.MouseButton1Click:Connect(function()
        isMin = not isMin
        if isMin then Main:TweenSize(UDim2.new(0, 250, 0, 35), "Out", "Quad", 0.15, true); ContentFrame.Visible = false; MinBtn.Text = "+"
        else Main:TweenSize(UDim2.new(0, 820, 0, 440), "Out", "Quad", 0.15, true); ContentFrame.Visible = true; MinBtn.Text = "_"; lastCount = -1 end
    end)

    ScreenGui.AncestryChanged:Connect(function(_, p) if not p then task.wait(0.5); CreateSpyUI() end end)
end

if not _G.KralldenHooksSet then
    local mt = getrawmetatable(game); local old = mt.__namecall; setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        local m = getnamecallmethod(); local a = {...}; local s = checkcaller()
        if _G.KralldenAddLog then
            if m:lower() == "fireserver" then task.spawn(_G.KralldenAddLog, self, a, s, "FS")
            elseif m:lower() == "fireclient" then task.spawn(_G.KralldenAddLog, self, a, s, "FC")
            elseif m:lower() == "invokeserver" then task.spawn(_G.KralldenAddLog, self, a, s, "IS") end
        end
        return old(self, ...)
    end); setreadonly(mt, true)
    _G.KralldenHooksSet = true
end

CreateSpyUI()
