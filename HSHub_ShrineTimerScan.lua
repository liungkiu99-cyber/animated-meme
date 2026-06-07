--[[
    HS HUB · ShrineTimerScan  —  find WHERE each shrine's cooldown value lives
    discord.gg/5rpP6faZSJ

    GOAL: read ALL shrine timers WITHOUT teleporting (like LUNAR). The tablet's
    "29m 58s" label is computed from a TARGET timestamp somewhere — this finds it.

    Dumps -> HSHub_ShrineTimerScan.json (+ clipboard):
      A) every LOADED shrine tablet: full attributes of the tablet + its folder +
         the TimerGui (every label's Text + attributes, any Value objects).   <- source
      B) ReplicatedStorage / _replicationFolder things named shrine/warden/artifact/
         timer/cooldown/active, + ValueObjects holding timestamp-ish numbers.
      C) resilient deep dump of TimerSync / ActiveTimerLabel / ArtifactUtils / Constants.

    USE: run anywhere, but BEST while standing at (or just after visiting) a shrine so
    a tablet is streamed in. Click SCAN again after moving to another shrine. Send me
    the JSON (or the COPY clipboard).
]]

if shared.__HSHub_ShrineTimerScan then pcall(function() shared.__HSHub_ShrineTimerScan:Destroy() end) end

local Players   = game:GetService('Players')
local RS        = game:GetService('ReplicatedStorage')
local Workspace = game:GetService('Workspace')
local HttpService = game:GetService('HttpService')
local LP = Players.LocalPlayer
local PG = LP:WaitForChild('PlayerGui')
local FILE = 'HSHub_ShrineTimerScan.json'

local SHRINE_NAMES = { Hellion=true,Boreal=true,Verdant=true,Novus=true,Garra=true,
                       Eigion=true,Ardor=true,Angelic=true,Shadow=true }

-- ═══ resilient serializer (per-field pcall, cycle + depth + width caps) ═══
local function ser(v, depth, seen)
    depth = depth or 0; seen = seen or {}
    local t = typeof(v)
    if t == 'number' or t == 'boolean' then return v end
    if t == 'string'   then return (#v > 220) and (v:sub(1, 220) .. '...') or v end
    if t == 'Vector3'  then return ('V3(%.1f,%.1f,%.1f)'):format(v.X, v.Y, v.Z) end
    if t == 'CFrame'   then local p = v.Position; return ('CF(%.1f,%.1f,%.1f)'):format(p.X, p.Y, p.Z) end
    if t == 'Instance' then return '<' .. v.ClassName .. ' ' .. v.Name .. '>' end
    if t == 'function' then return '<fn>' end
    if t == 'EnumItem' then return tostring(v) end
    if t == 'table' then
        if seen[v] then return '<cycle>' end
        if depth >= 4 then return '<deep>' end
        seen[v] = true
        local out, n = {}, 0
        pcall(function()
            for k, val in pairs(v) do
                n = n + 1; if n > 50 then out['_more'] = 'truncated'; break end
                local ok, r = pcall(ser, val, depth + 1, seen)
                out[tostring(k)] = ok and r or '<err>'
            end
        end)
        seen[v] = nil
        return out
    end
    return tostring(v)
end

local function attrs(inst)
    local a, has = {}, false
    pcall(function() for k, val in pairs(inst:GetAttributes()) do a[k] = ser(val); has = true end end)
    return has and a or nil
end

-- ═══ A) loaded shrine tablets (the countdown source) ═══
local function dumpTablets()
    local out = {}
    local i = Workspace:FindFirstChild('Interactions'); if not i then return out end
    local shrines = i:FindFirstChild('Warden Shrines'); if not shrines then return out end
    out._root_attrs = attrs(shrines)
    for _, folder in ipairs(shrines:GetChildren()) do
        local entry = { folder = folder.Name, folder_attrs = attrs(folder), parts = {}, timerguis = {}, values = {} }
        for _, d in ipairs(folder:GetDescendants()) do
            if d:IsA('BasePart') then
                entry.parts[#entry.parts + 1] = { name = d.Name, class = d.ClassName, pos = ser(d.Position), attrs = attrs(d) }
            elseif d:IsA('BillboardGui') or d:IsA('SurfaceGui') or d.Name:lower():find('timer') then
                local g = { name = d.Name, class = d.ClassName, attrs = attrs(d), labels = {} }
                for _, c in ipairs(d:GetDescendants()) do
                    if c:IsA('TextLabel') or c:IsA('TextButton') then
                        local txt = '?'; pcall(function() txt = c.Text end)
                        g.labels[#g.labels + 1] = { name = c.Name, text = txt, attrs = attrs(c) }
                    elseif c:IsA('ValueBase') then
                        g.labels[#g.labels + 1] = { name = c.Name, class = c.ClassName, value = ser(c.Value) }
                    end
                end
                entry.timerguis[#entry.timerguis + 1] = g
            elseif d:IsA('ValueBase') then
                entry.values[#entry.values + 1] = { name = d.Name, class = d.ClassName, value = ser(d.Value), parent = d.Parent and d.Parent.Name }
            end
        end
        out[#out + 1] = entry
    end
    return out
end

-- ═══ B) ReplicatedStorage scan for shrine/timer values ═══
local function scanRS()
    local hits = {}
    local roots = { RS }
    local rf = RS:FindFirstChild('_replicationFolder'); if rf then roots[#roots + 1] = rf end
    for _, root in ipairs(roots) do
        pcall(function()
            for _, d in ipairs(root:GetDescendants()) do
                if #hits > 140 then break end
                local ln = d.Name:lower()
                local nameHit = ln:find('shrine') or ln:find('warden') or ln:find('artifact')
                    or ln:find('cooldown') or ln:find('timer') or ln:find('offer') or SHRINE_NAMES[d.Name]
                if d:IsA('ValueBase') then
                    local big = (typeof(d.Value) == 'number' and d.Value > 1e9)   -- looks like a timestamp
                    if nameHit or big then
                        hits[#hits + 1] = { path = d:GetFullName(), class = d.ClassName, value = ser(d.Value), attrs = attrs(d) }
                    end
                elseif nameHit and not d:IsA('LuaSourceContainer') then
                    hits[#hits + 1] = { path = d:GetFullName(), class = d.ClassName, attrs = attrs(d) }
                end
            end
        end)
    end
    return hits
end

-- ═══ C) deep-dump the timer modules (cached require = safe) ═══
local function findModule(name)
    for _, root in ipairs({ RS:FindFirstChild('_replicationFolder'), RS, Players.LocalPlayer:FindFirstChild('PlayerScripts') }) do
        if root then
            local found
            pcall(function()
                for _, d in ipairs(root:GetDescendants()) do
                    if d:IsA('ModuleScript') and d.Name == name then found = d; break end
                end
            end)
            if found then return found end
        end
    end
end
local function dumpModules()
    local out = {}
    for _, name in ipairs({ 'TimerSync', 'ActiveTimerLabel', 'ArtifactUtils', 'WardenShrine', 'Constants', 'ReplicatedStateTracker' }) do
        local ms = findModule(name)
        if not ms then out[name] = '<not found>'
        else
            local ok, m = pcall(require, ms)
            out[name] = ok and ser(m, 0, {}) or ('<require err: ' .. tostring(m) .. '>')
        end
    end
    return out
end

-- ═══ run + write + clipboard ═══
local result = { tablets = {}, rs = {}, modules = {}, place = game.PlaceId }
local summary = '...'
local function runScan()
    result.tablets = dumpTablets()
    result.rs      = scanRS()
    result.modules = dumpModules()
    local nTab = 0; for k in pairs(result.tablets) do if type(k) == 'number' then nTab = nTab + 1 end end
    summary = ('tablets:%d  rs_hits:%d'):format(nTab, #result.rs)
    local json = '{}'
    pcall(function() json = HttpService:JSONEncode(result) end)
    pcall(function() if writefile then writefile(FILE, json) end end)
    pcall(function() if setclipboard then setclipboard(json) end end)
    return summary, #json
end

-- ═══ minimal UI ═══
local gui = Instance.new('ScreenGui'); gui.Name = 'HSHub_ShrineTimerScan_' .. math.random(1e5, 1e6)
gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true; gui.Parent = (gethui and gethui()) or PG
shared.__HSHub_ShrineTimerScan = gui
local frame = Instance.new('Frame', gui); frame.Size = UDim2.new(0, 330, 0, 150); frame.Position = UDim2.new(0, 20, 0, 90)
frame.BackgroundColor3 = Color3.fromRGB(18, 20, 28); frame.BorderSizePixel = 0; frame.Active = true; frame.Draggable = true
Instance.new('UICorner', frame).CornerRadius = UDim.new(0, 10); Instance.new('UIStroke', frame).Color = Color3.fromRGB(150, 120, 220)
local hdr = Instance.new('Frame', frame); hdr.Size = UDim2.new(1, 0, 0, 34); hdr.BackgroundColor3 = Color3.fromRGB(120, 90, 190); hdr.BorderSizePixel = 0
Instance.new('UICorner', hdr).CornerRadius = UDim.new(0, 10)
local ttl = Instance.new('TextLabel', hdr); ttl.BackgroundTransparency = 1; ttl.Size = UDim2.new(1, -40, 1, 0); ttl.Position = UDim2.new(0, 12, 0, 0)
ttl.Font = Enum.Font.GothamBold; ttl.TextSize = 13; ttl.TextColor3 = Color3.fromRGB(245, 245, 250); ttl.TextXAlignment = Enum.TextXAlignment.Left; ttl.Text = 'HS HUB · ShrineTimerScan'
local xB = Instance.new('TextButton', hdr); xB.BackgroundTransparency = 1; xB.Size = UDim2.new(0, 34, 0, 34); xB.Position = UDim2.new(1, -36, 0, 0)
xB.Font = Enum.Font.GothamBold; xB.TextSize = 20; xB.TextColor3 = Color3.fromRGB(255, 255, 255); xB.Text = '×'
xB.MouseButton1Click:Connect(function() gui:Destroy(); shared.__HSHub_ShrineTimerScan = nil end)
local info = Instance.new('TextLabel', frame); info.BackgroundTransparency = 1; info.Size = UDim2.new(1, -20, 0, 60); info.Position = UDim2.new(0, 12, 0, 42)
info.Font = Enum.Font.Code; info.TextSize = 12; info.TextColor3 = Color3.fromRGB(190, 215, 235); info.TextWrapped = true
info.TextXAlignment = Enum.TextXAlignment.Left; info.TextYAlignment = Enum.TextYAlignment.Top
info.Text = 'Stand at/near a shrine for best data. Tap SCAN.'
local function mkBtn(lbl, col, x, w)
    local b = Instance.new('TextButton', frame); b.Size = UDim2.new(0, w, 0, 30); b.Position = UDim2.new(0, x, 1, -40)
    b.BackgroundColor3 = col; b.BorderSizePixel = 0; b.Font = Enum.Font.GothamBold; b.TextSize = 12; b.TextColor3 = Color3.fromRGB(245, 245, 250); b.Text = lbl
    Instance.new('UICorner', b).CornerRadius = UDim.new(0, 6); return b
end
local scanB = mkBtn('🔍 SCAN', Color3.fromRGB(120, 90, 190), 12, 150)
local copyB = mkBtn('📋 COPY', Color3.fromRGB(60, 130, 110), 170, 148)
scanB.MouseButton1Click:Connect(function() task.spawn(function()
    info.Text = 'scanning...'
    local s, len = runScan()
    info.Text = ('done: %s\nsaved %s (%d chars)\n+ copied to clipboard. send me the file.'):format(s, FILE, len)
end) end)
copyB.MouseButton1Click:Connect(function()
    local json = '{}'; pcall(function() json = HttpService:JSONEncode(result) end)
    pcall(function() if setclipboard then setclipboard(json) end end)
    info.Text = 'copied JSON to clipboard again.'
end)
task.spawn(function() task.wait(0.5); local s, len = runScan(); info.Text = ('auto-scan: %s\nsaved %s (%d chars). Move to a shrine + SCAN again for more.'):format(s, FILE, len) end)
