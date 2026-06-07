--[[
    HS HUB · ButtonScan  —  find the exact Name + coords of ANY on-screen button
    discord.gg/5rpP6faZSJ

    PURPOSE: make Restart fully auto (like Play needs only calibration). Open the
    popup you care about (e.g. the Restart "confirm" dialog), press SCAN, and read
    every VISIBLE TextButton/ImageButton across ALL of PlayerGui:
        [ScreenGui] ButtonName  'visible text'  center(cx,cy)  size(w,h)
    Tell me the confirm button's Name → I hardcode findNamed('<Name>') in the hub.

    Also: type X,Y → TAP (genuine VIM) to verify a coordinate hits the button.
    A name filter narrows the list (type "confirm"/"restart"/"yes", or blank = all).
    Reusable — do not overwrite; new experiments get a new filename.
]]

if shared.__HSHub_ButtonScan then pcall(function() shared.__HSHub_ButtonScan:Destroy() end) end

local Players    = game:GetService('Players')
local UIS        = game:GetService('UserInputService')
local GuiService = game:GetService('GuiService')
local LP = Players.LocalPlayer
local PG = LP:WaitForChild('PlayerGui')

local IS_PC = false
pcall(function() local p = UIS:GetPlatform()
    if p == Enum.Platform.Windows or p == Enum.Platform.OSX or p == Enum.Platform.UWP then IS_PC = true end end)
if not IS_PC and not UIS.TouchEnabled then IS_PC = true end
local VIM; pcall(function() VIM = game:GetService('VirtualInputManager') end)
local INSET = Vector2.new(0, 0); pcall(function() INSET = GuiService:GetGuiInset() end)

local logFn, hideUI, showUI

-- ═══ genuine VIM tap (same method as TapTester) ═══
local function vimTap(x, y)
    if not VIM then return end
    if IS_PC then
        pcall(function() if VIM.SendMouseMoveEvent then VIM:SendMouseMoveEvent(x, y, game) end end)
        pcall(function() VIM:SendMouseButtonEvent(x, y, 0, true, game, 1) end)
        task.wait(0.06)
        pcall(function() VIM:SendMouseButtonEvent(x, y, 0, false, game, 1) end)
    else
        pcall(function() VIM:SendMouseButtonEvent(x, y, 0, true, game, 1) end)
        task.wait(0.05)
        pcall(function() VIM:SendMouseButtonEvent(x, y, 0, false, game, 1) end)
        pcall(function() VIM:SendTouchEvent(1, 0, x, y) end)
        task.wait(0.06)
        pcall(function() VIM:SendTouchEvent(1, 2, x, y) end)
    end
end
local function tapAt(x, y)
    logFn(('TAP @(%d,%d)'):format(math.floor(x), math.floor(y)))
    hideUI(); task.wait(0.1)
    vimTap(x, y)
    task.wait(0.1); showUI()
end

-- ═══ scan: every VISIBLE button across PlayerGui (+ gethui) ═══
local function visibleChain(o)
    local n = o
    while n and n:IsA('GuiObject') do if not n.Visible then return false end n = n.Parent end
    return true
end
local function topScreenGui(o)
    local n = o
    while n and n.Parent and not n:IsA('ScreenGui') do n = n.Parent end
    return (n and n:IsA('ScreenGui')) and n.Name or '?'
end
local function scanButtons(filter)
    filter = (filter and filter ~= '') and filter:lower() or nil
    local roots, seen = {}, {}
    table.insert(roots, PG)
    if gethui then local ok, h = pcall(gethui); if ok and h then table.insert(roots, h) end end
    local found = {}
    for _, root in ipairs(roots) do
        for _, d in ipairs(root:GetDescendants()) do
            if (d:IsA('TextButton') or d:IsA('ImageButton')) and not seen[d] and visibleChain(d) then
                seen[d] = true
                local ap, az = d.AbsolutePosition, d.AbsoluteSize
                if az.X > 0 and az.Y > 0 then
                    local nm = d.Name
                    local sg = topScreenGui(d)
                    local txt = ''
                    if d:IsA('TextButton') then pcall(function() txt = d.Text end) end
                    local hay = (sg .. ' ' .. nm .. ' ' .. txt):lower()
                    if (not filter) or hay:find(filter, 1, true) then
                        found[#found + 1] = {
                            sg = sg, name = nm, text = txt,
                            cx = ap.X + az.X / 2, cy = ap.Y + az.Y / 2,
                            w = az.X, h = az.Y,
                        }
                    end
                end
            end
        end
    end
    table.sort(found, function(a, b) if a.sg ~= b.sg then return a.sg < b.sg end return a.cy < b.cy end)
    return found
end

-- ═══ UI ═══
local gui = Instance.new('ScreenGui'); gui.Name = 'HSHub_ButtonScan_' .. math.random(1e5, 1e6)
gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true; gui.Parent = (gethui and gethui()) or PG
shared.__HSHub_ButtonScan = gui
local frame = Instance.new('Frame', gui); frame.Size = UDim2.new(0, 380, 0, 360); frame.Position = UDim2.new(0, 20, 0, 70)
frame.BackgroundColor3 = Color3.fromRGB(18, 20, 28); frame.BorderSizePixel = 0; frame.Active = true; frame.Draggable = true
Instance.new('UICorner', frame).CornerRadius = UDim.new(0, 10); Instance.new('UIStroke', frame).Color = Color3.fromRGB(120, 160, 230)
local hdr = Instance.new('Frame', frame); hdr.Size = UDim2.new(1, 0, 0, 36); hdr.BackgroundColor3 = Color3.fromRGB(70, 110, 190); hdr.BorderSizePixel = 0
Instance.new('UICorner', hdr).CornerRadius = UDim.new(0, 10)
local ttl = Instance.new('TextLabel', hdr); ttl.BackgroundTransparency = 1; ttl.Size = UDim2.new(1, -44, 1, 0); ttl.Position = UDim2.new(0, 12, 0, 0)
ttl.Font = Enum.Font.GothamBold; ttl.TextSize = 14; ttl.TextColor3 = Color3.fromRGB(245, 245, 250); ttl.TextXAlignment = Enum.TextXAlignment.Left; ttl.Text = 'HS HUB · ButtonScan'
local xB = Instance.new('TextButton', hdr); xB.BackgroundTransparency = 1; xB.Size = UDim2.new(0, 34, 0, 34); xB.Position = UDim2.new(1, -38, 0, 1)
xB.Font = Enum.Font.GothamBold; xB.TextSize = 20; xB.TextColor3 = Color3.fromRGB(255, 255, 255); xB.Text = '×'
xB.MouseButton1Click:Connect(function() gui:Destroy(); shared.__HSHub_ButtonScan = nil end)

local function mkBox(ph, x, w, y, val)
    local b = Instance.new('TextBox', frame); b.Size = UDim2.new(0, w, 0, 28); b.Position = UDim2.new(0, x, 0, y)
    b.BackgroundColor3 = Color3.fromRGB(30, 34, 44); b.BorderSizePixel = 0; b.Font = Enum.Font.Code; b.TextSize = 14
    b.TextColor3 = Color3.fromRGB(230, 240, 230); b.PlaceholderText = ph; b.Text = val or ''; b.ClearTextOnFocus = false
    Instance.new('UICorner', b).CornerRadius = UDim.new(0, 6); return b
end
local function mkBtn(lbl, col, x, w, y)
    local b = Instance.new('TextButton', frame); b.Size = UDim2.new(0, w, 0, 28); b.Position = UDim2.new(0, x, 0, y)
    b.BackgroundColor3 = col; b.BorderSizePixel = 0; b.Font = Enum.Font.GothamBold; b.TextSize = 12; b.TextColor3 = Color3.fromRGB(245, 245, 250); b.Text = lbl
    Instance.new('UICorner', b).CornerRadius = UDim.new(0, 6); return b
end
-- row 1: filter + SCAN
local filterBox = mkBox('name filter (blank=all)', 12, 230, 44)
local scanBtn   = mkBtn('🔍 SCAN buttons', Color3.fromRGB(70, 120, 180), 250, 118, 44)
-- row 2: X / Y + TAP
local boxX = mkBox('X', 12, 70, 80)
local boxY = mkBox('Y', 88, 70, 80)
local tapBtn = mkBtn('👆 TAP typed', Color3.fromRGB(60, 160, 110), 168, 200, 80)

local infoLbl = Instance.new('TextLabel', frame); infoLbl.BackgroundTransparency = 1; infoLbl.Size = UDim2.new(1, -20, 0, 16); infoLbl.Position = UDim2.new(0, 12, 0, 114)
infoLbl.Font = Enum.Font.Code; infoLbl.TextSize = 11; infoLbl.TextColor3 = Color3.fromRGB(150, 200, 230); infoLbl.TextXAlignment = Enum.TextXAlignment.Left
pcall(function()
    local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(0, 0)
    infoLbl.Text = ('viewport %dx%d  inset.Y=%d  %s   · c=center(AbsolutePos)'):format(math.floor(vp.X), math.floor(vp.Y), math.floor(INSET.Y), IS_PC and 'PC' or 'MOBILE')
end)

local scroll = Instance.new('ScrollingFrame', frame); scroll.Size = UDim2.new(1, -18, 0, 190); scroll.Position = UDim2.new(0, 9, 0, 134)
scroll.BackgroundColor3 = Color3.fromRGB(11, 13, 19); scroll.BorderSizePixel = 0; scroll.ScrollBarThickness = 4
Instance.new('UICorner', scroll).CornerRadius = UDim.new(0, 6)
local lo = Instance.new('UIListLayout', scroll); lo.Padding = UDim.new(0, 2); lo.SortOrder = Enum.SortOrder.LayoutOrder
local pd = Instance.new('UIPadding', scroll); pd.PaddingTop = UDim.new(0, 4); pd.PaddingLeft = UDim.new(0, 6)
logFn = function(t, col)
    local lb = Instance.new('TextLabel', scroll); lb.BackgroundTransparency = 1; lb.Size = UDim2.new(1, -12, 0, 15); lb.LayoutOrder = #scroll:GetChildren()
    lb.Font = Enum.Font.Code; lb.TextSize = 11; lb.TextColor3 = col or Color3.fromRGB(190, 215, 235); lb.TextXAlignment = Enum.TextXAlignment.Left; lb.TextTruncate = Enum.TextTruncate.AtEnd; lb.Text = t
    scroll.CanvasSize = UDim2.new(0, 0, 0, #scroll:GetChildren() * 17); scroll.CanvasPosition = Vector2.new(0, scroll.CanvasSize.Y.Offset)
end
hideUI = function() frame.Visible = false end
showUI = function() frame.Visible = true end

logFn('Open the popup (e.g. Restart confirm), then press SCAN.', Color3.fromRGB(255, 210, 120))
logFn('Tell me the confirm button Name → restart becomes auto.', Color3.fromRGB(255, 210, 120))

scanBtn.MouseButton1Click:Connect(function() task.spawn(function()
    local list = scanButtons(filterBox.Text)
    logFn(('── %d visible buttons ──'):format(#list), Color3.fromRGB(120, 210, 255))
    for _, b in ipairs(list) do
        logFn(('[%s] %s %s c(%d,%d) s(%dx%d)'):format(
            b.sg, b.name,
            (b.text ~= '' and ("'" .. b.text .. "'") or ''),
            math.floor(b.cx), math.floor(b.cy), math.floor(b.w), math.floor(b.h)))
    end
end) end)
tapBtn.MouseButton1Click:Connect(function() task.spawn(function()
    local x, y = tonumber(boxX.Text), tonumber(boxY.Text)
    if x and y then tapAt(x, y) else logFn('type valid X and Y first', Color3.fromRGB(255, 140, 140)) end
end) end)
