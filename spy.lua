local ScreenGui = Instance.new("ScreenGui")
local MainFrame = Instance.new("Frame")
local Title = Instance.new("TextLabel")
local RemoteList = Instance.new("ScrollingFrame")
local UIListLayout = Instance.new("UIListLayout")
local DetailsFrame = Instance.new("Frame")
local DetailsText = Instance.new("TextBox")
local CopyBtn = Instance.new("TextButton")

-- Свойства GUI
ScreenGui.Parent = game:GetService("CoreGui")
ScreenGui.Name = "QuantumSpyUI"

MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.Position = UDim2.new(0.5, -150, 0.5, -100)
MainFrame.Size = UDim2.new(0, 400, 0, 300)
MainFrame.Active = true
MainFrame.Draggable = true -- Включаем перетаскивание мышью

Title.Parent = MainFrame
Title.Size = UDim2.new(1, 0, 0, 30)
Title.Text = "QUANTUM SPY v2"
Title.TextColor3 = Color3.new(1, 1, 1)
Title.BackgroundColor3 = Color3.fromRGB(45, 45, 45)

RemoteList.Parent = MainFrame
RemoteList.Position = UDim2.new(0, 5, 0, 35)
RemoteList.Size = UDim2.new(0, 150, 1, -40)
RemoteList.CanvasSize = UDim2.new(0, 0, 10, 0)
RemoteList.ScrollBarThickness = 5

UIListLayout.Parent = RemoteList
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder

DetailsFrame.Parent = MainFrame
DetailsFrame.Position = UDim2.new(0, 160, 0, 35)
DetailsFrame.Size = UDim2.new(1, -165, 1, -40)
DetailsFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)

DetailsText.Parent = DetailsFrame
DetailsText.Size = UDim2.new(1, 0, 0.8, 0)
DetailsText.BackgroundTransparency = 1
DetailsText.TextColor3 = Color3.new(0.8, 0.8, 0.8)
DetailsText.TextWrapped = true
DetailsText.ClearTextOnFocus = false
DetailsText.TextXAlignment = Enum.TextXAlignment.Left
DetailsText.TextYAlignment = Enum.TextYAlignment.Top
DetailsText.MultiLine = true
DetailsText.Text = "Выберите Remote для просмотра..."

CopyBtn.Parent = DetailsFrame
CopyBtn.Position = UDim2.new(0, 5, 0.85, 0)
CopyBtn.Size = UDim2.new(1, -10, 0.1, 0)
CopyBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
CopyBtn.Text = "COPY TO CLIPBOARD"
CopyBtn.TextColor3 = Color3.new(1, 1, 1)

-- Логика перехвата
local capturedData = {}

local function addRemoteButton(remote, args)
    local btn = Instance.new("TextButton")
    btn.Parent = RemoteList
    btn.Size = UDim2.new(1, 0, 0, 25)
    btn.Text = remote.Name
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    btn.TextColor3 = Color3.new(1, 1, 1)
    
    btn.MouseButton1Click:Connect(function()
        local info = "Path: " .. remote:GetFullName() .. "\n\nArgs:\n"
        for i, v in pairs(args) do
            info = info .. "[" .. i .. "] (" .. typeof(v) .. "): " .. tostring(v) .. "\n"
        end
        DetailsText.Text = info
    end)
end

CopyBtn.MouseButton1Click:Connect(function()
    setclipboard(DetailsText.Text)
    CopyBtn.Text = "COPIED!"
    wait(1)
    CopyBtn.Text = "COPY TO CLIPBOARD"
end)

-- ХУК МЕТАТАБЛИЦЫ
local mt = getrawmetatable(game)
local oldNamecall = mt.__namecall
setreadonly(mt, false)

mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if (method == "FireServer" or method == "fireServer") and not checkcaller() then
        -- Добавляем в UI
        addRemoteButton(self, args)
    end

    -- ВАЖНО: Возвращаем оригинальный вызов, чтобы действие в игре сработало!
    return oldNamecall(self, ...)
end)

setreadonly(mt, true)
