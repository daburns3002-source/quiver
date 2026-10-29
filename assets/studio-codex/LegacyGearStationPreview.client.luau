--!strict
-- Gear Station preview for the older live place. Equipment stays server owned.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Run = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local Tween = game:GetService("TweenService")
local player = Players.LocalPlayer
local lobby = require(RS.Shared.Config.Lobby)
local art = require(RS.Shared.Config.ShopAssets)
local gui = Instance.new("ScreenGui")
gui.Name = "GearStationPreview"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 125
gui.Parent = player:WaitForChild("PlayerGui")
local function box(parent: Instance, name: string, pos: UDim2, size: UDim2, color: Color3): Frame
	local f = Instance.new("Frame")
	f.Name, f.Position, f.Size, f.BackgroundColor3, f.BorderSizePixel = name, pos, size, color, 0
	f.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = f
	return f
end
local function label(parent: Instance, words: string, pos: UDim2, size: UDim2, color: Color3?): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency, t.Text, t.Position, t.Size = 1, words, pos, size
	t.Font, t.TextScaled, t.TextColor3 = Enum.Font.Arcade, true, color or Color3.new(1, 1, 1)
	t.Parent = parent
	return t
end
local function border(parent: Instance, color: Color3, thick: number)
	local s = Instance.new("UIStroke")
	s.Color, s.Thickness = color, thick
	s.Parent = parent
end
local function button(parent: Instance, words: string, pos: UDim2, size: UDim2, color: Color3, action: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Name, b.Text, b.Position, b.Size = words, words, pos, size
	b.Font, b.TextScaled, b.TextColor3 = Enum.Font.Arcade, true, Color3.new(1, 1, 1)
	b.BackgroundColor3, b.BorderSizePixel, b.AutoButtonColor = color, 0, false
	b.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = b
	local scale = Instance.new("UIScale")
	scale.Parent = b
	b.MouseEnter:Connect(function() Tween:Create(scale, TweenInfo.new(.12), {Scale=1.05}):Play() end)
	b.MouseLeave:Connect(function() Tween:Create(scale, TweenInfo.new(.12), {Scale=1}):Play() end)
	b.Activated:Connect(function()
		Tween:Create(scale,TweenInfo.new(.07),{Scale=.9}):Play()
		task.delay(.08,function() if scale.Parent then Tween:Create(scale,TweenInfo.new(.14),{Scale=1}):Play() end end)
		action()
	end)
	return b
end
local prompt = button(gui, "E  GEAR", UDim2.fromScale(.43,.84), UDim2.fromScale(.14,.07), Color3.fromRGB(219,157,39), function() end)
prompt.Visible = false
border(prompt, Color3.fromRGB(255,230,137),3)
local root = box(gui,"GearPanel",UDim2.fromScale(.5,.5),UDim2.fromOffset(1100,680),Color3.fromRGB(17,26,49))
root.AnchorPoint = Vector2.new(.5,.5)
root.Visible = false
border(root,Color3.fromRGB(234,184,70),4)
local rootScale = Instance.new("UIScale")
rootScale.Parent = root
local function fit()
	local camera = workspace.CurrentCamera
	if camera then
		local view = camera.ViewportSize
		rootScale.Scale = math.min((view.X-24)/1100,(view.Y-24)/680,1)
	end
end
fit()
local backdrop = box(root,"Showcase",UDim2.fromOffset(18,72),UDim2.fromOffset(1064,260),Color3.fromRGB(32,56,78))
local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new(Color3.fromRGB(54,83,88),Color3.fromRGB(16,30,57))
grad.Rotation = 90
grad.Parent = backdrop
label(root,"GEAR",UDim2.fromOffset(370,12),UDim2.fromOffset(360,54),Color3.fromRGB(255,210,81))
button(root,"X",UDim2.fromOffset(1020,15),UDim2.fromOffset(52,50),Color3.fromRGB(189,47,64),function() root.Visible=false end)
local avatar = Instance.new("ViewportFrame")
avatar.Name="YourCharacter"
avatar.BackgroundTransparency=1
avatar.Position,avatar.Size=UDim2.fromOffset(420,80),UDim2.fromOffset(260,245)
avatar.Parent=backdrop
local function showAvatar()
	avatar:ClearAllChildren()
	local character=player.Character
	if not character then return end
	local old=character.Archivable
	character.Archivable=true
	local copy=character:Clone()
	character.Archivable=old
	for _,v in copy:GetDescendants() do
		if v:IsA("LuaSourceContainer") then v:Destroy()
		elseif v:IsA("BasePart") then v.Anchored=true;v.CanCollide=false;v.LocalTransparencyModifier=0 end
	end
	local world=Instance.new("WorldModel")
	world.Parent=avatar
	copy.Parent=world
	copy:PivotTo(CFrame.new())
	local camera=Instance.new("Camera")
	camera.CFrame=CFrame.lookAt(Vector3.new(0,2,-9),Vector3.new(0,2,0))
	camera.Parent=avatar
	avatar.CurrentCamera=camera
end
local function slot(name:string,x:number,y:number,icon:string?,color:Color3,click:()->())
	local s=box(backdrop,name.."Slot",UDim2.fromOffset(x,y),UDim2.fromOffset(135,96),color)
	border(s,color:Lerp(Color3.new(1,1,1),.5),3)
	if icon and icon~="" then
		local im=Instance.new("ImageLabel")
		im.BackgroundTransparency=1;im.Image=icon
		im.Position,im.Size=UDim2.fromScale(.2,.05),UDim2.fromScale(.6,.68)
		im.Parent=s
	else label(s,"+",UDim2.fromScale(.35,.08),UDim2.fromScale(.3,.55)) end
	label(s,name,UDim2.fromScale(.05,.75),UDim2.fromScale(.9,.2))
	local hit=button(s,"",UDim2.fromScale(0,0),UDim2.fromScale(1,1),Color3.new(0,0,0),click)
	hit.BackgroundTransparency=1
	return s
end
local selected="WEAPONS"
local grid=Instance.new("ScrollingFrame")
grid.Name="InventoryGrid";grid.Position=UDim2.fromOffset(35,392);grid.Size=UDim2.fromOffset(1030,245)
grid.BackgroundTransparency=1;grid.ScrollBarThickness=7;grid.AutomaticCanvasSize=Enum.AutomaticSize.Y
grid.CanvasSize=UDim2.fromScale(0,0);grid.Parent=root
local layout=Instance.new("UIGridLayout")
layout.CellSize=UDim2.fromOffset(185,180);layout.CellPadding=UDim2.fromOffset(18,15)
layout.Parent=grid
local tabs=box(root,"Tabs",UDim2.fromOffset(22,344),UDim2.fromOffset(1056,43),Color3.fromRGB(10,18,38))
local function draw()
	for _,child in grid:GetChildren() do if child:IsA("GuiObject") then child:Destroy() end end
	if selected=="TRAILS" then
		label(grid,"TRAILS COMING SOON",UDim2.fromOffset(0,0),UDim2.fromOffset(750,85))
		return
	end
	if selected=="PETS" then
		local pets={"Moss Slime","Acorn Buddy","Glade Fox","Ember Wilf","Slime Prince","Glimmerhorn"}
		for i,name in pets do
			local c=box(grid,"Pet"..i,UDim2.new(),UDim2.fromOffset(185,180),Color3.fromRGB(54+i*8,94+i*9,95+i*8))
			border(c,Color3.fromRGB(148,245,196),3)
			label(c,name:upper(),UDim2.fromScale(.08,.72),UDim2.fromScale(.84,.2))
		end
	else
		local weapons={"MossSlimeBow","FireflyBow","GladeSpiritBow","HootmossStaff","ThornBlade","AcornBow","TwigBow","EmberFangBow"}
		for i,key in weapons do
			local c=box(grid,key,UDim2.new(),UDim2.fromOffset(185,180),Color3.fromRGB(46+i*4,67+i*5,103+i*5))
			border(c,Color3.fromRGB(96,194,255),3)
			local image=Instance.new("ImageLabel")
			image.BackgroundTransparency=1;image.Image=art.weapons[key] or ""
			image.Position,image.Size=UDim2.fromScale(.12,.06),UDim2.fromScale(.76,.67)
			image.Parent=c
			label(c,key:upper(),UDim2.fromScale(.05,.76),UDim2.fromScale(.9,.18))
		end
	end
end
slot("WEAPON",55,30,art.weapons.MossSlimeBow,Color3.fromRGB(48,127,192),function() selected="WEAPONS";draw() end)
slot("TRAIL",55,145,nil,Color3.fromRGB(68,77,98),function() selected="TRAILS";draw() end)
slot("PET 1",874,30,nil,Color3.fromRGB(70,164,103),function() selected="PETS";draw() end)
slot("PET 2",874,145,nil,Color3.fromRGB(70,164,103),function() selected="PETS";draw() end)
for i,name in {"WEAPONS","PETS","TRAILS"} do
	button(tabs,name,UDim2.fromOffset(10+(i-1)*350,2),UDim2.fromOffset(335,39),Color3.fromRGB(145,97,25),function() selected=name;draw() end)
end
draw()
local open=false
prompt.Activated:Connect(function() open=true;root.Visible=true;showAvatar();draw() end)
Input.InputBegan:Connect(function(key,processed)
	if processed then return end
	if key.KeyCode==Enum.KeyCode.E and prompt.Visible then open=true;root.Visible=true;showAvatar();draw() end
	if key.KeyCode==Enum.KeyCode.Escape then root.Visible=false;open=false end
end)
local target=Vector3.new(lobby.origin.X+86,lobby.origin.Y+3,lobby.origin.Z+6)
Run.RenderStepped:Connect(function()
	local rootPart=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local near=rootPart and (rootPart.Position-target).Magnitude<17
	prompt.Visible=near==true and not root.Visible
	if root.Visible and not near then root.Visible=false;open=false end
	fit()
end)
