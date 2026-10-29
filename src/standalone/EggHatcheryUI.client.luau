-- Native hatchery UI. Presentation only until server egg transactions exist.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Run=game:GetService('RunService')
local Input=game:GetService('UserInputService')
local Tween=game:GetService('TweenService')
local player=Players.LocalPlayer
local pg=player:WaitForChild('PlayerGui')
local Lobby=require(RS.Shared.Config.Lobby)
local Assets=require(RS.Shared.Config.ShopAssets)
local Rarities=require(RS.Shared.Config.Rarities)
local PetCombat=require(RS.Shared.Config.PetCombat)
local INK=Color3.fromRGB(7,60,80)
local WHITE=Color3.fromRGB(248,253,255)
local function frame(p,n,x,y,w,h,c,z)
 local f=Instance.new('Frame');f.Name=n;f.BorderSizePixel=0;f.Position=UDim2.fromOffset(x,y);f.Size=UDim2.fromOffset(w,h);f.BackgroundTransparency=c and 0 or 1;f.BackgroundColor3=c or WHITE;f.ZIndex=z or 1;f.Parent=p;return f
end
local function text(p,s,x,y,w,h,size,c,z)
 local t=Instance.new('TextLabel');t.Name=s;t.BackgroundTransparency=1;t.Position=UDim2.fromOffset(x,y);t.Size=UDim2.fromOffset(w,h);t.Text=s;t.Font=Enum.Font.GothamBold;t.TextSize=size;t.TextColor3=c or WHITE;t.TextXAlignment=Enum.TextXAlignment.Center;t.TextYAlignment=Enum.TextYAlignment.Center;t.ZIndex=z or 10;t.Parent=p
 local st=Instance.new('UIStroke');st.Color=INK;st.Thickness=size>=30 and 1.5 or .8;st.Parent=t;return t
end
-- Five horizontal strips form a stepped silhouette, with an inset face.
local function pixel(p,n,x,y,w,h,c,z)
 local f=frame(p,n,x,y,w,h,nil,z)
 local function strips(parent,name,inset,col,level)
  local q=6;local hh=h-inset*2;local ww=w-inset*2
  for i,r in ipairs({{q*2,0,ww-q*4,q},{q,q,ww-q*2,q},{0,q*2,ww,hh-q*4},{q,hh-q*2,ww-q*2,q},{q*2,hh-q,ww-q*4,q}}) do
   frame(parent,name..i,r[1]+inset,r[2]+inset,r[3],r[4],col,level)
  end
 end
 strips(f,'Border',0,INK,z);strips(f,'Face',3,c,z+1)
 return f
end
local gui=Instance.new('ScreenGui');gui.Name='EggHatcheryUI';gui.ResetOnSpawn=false;gui.IgnoreGuiInset=true;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.DisplayOrder=116;gui.Parent=pg
local root=frame(gui,'HatcheryLayout',0,0,1200,720,nil,1);root.AnchorPoint=Vector2.new(.5,.5);root.Position=UDim2.fromScale(.5,.5);root.Visible=false
local rootScale=Instance.new('UIScale');rootScale.Parent=root
local layoutScale=1
local popupScale=Instance.new('NumberValue');popupScale.Name='PopupScale';popupScale.Value=1;popupScale.Parent=root
popupScale.Changed:Connect(function(value) rootScale.Scale=layoutScale*value end)
local popupTween
root:GetPropertyChangedSignal('Visible'):Connect(function()
 if popupTween then popupTween:Cancel();popupTween=nil end
 if root.Visible then
  popupScale.Value=.72
  popupTween=Tween:Create(popupScale,TweenInfo.new(.34,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Value=1})
  popupTween:Play()
 else popupScale.Value=1 end
end)
local function fit() local cam=workspace.CurrentCamera;if cam then local v=cam.ViewportSize;layoutScale=math.min((v.X-24)/1200,(v.Y-32)/720,1.12);rootScale.Scale=layoutScale*popupScale.Value end end
fit();if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal('ViewportSize'):Connect(fit) end
local layer=frame(gui,'ClickBursts',0,0,0,0,nil,50);layer.Size=UDim2.fromScale(1,1)
local activeParticles=0
local function burst(button,inputObject)
 if activeParticles>=60 then return end
 local middle=button.AbsolutePosition+button.AbsoluteSize/2
 if inputObject and inputObject.UserInputType==Enum.UserInputType.MouseButton1 then
  -- Mouse location uses full-screen coordinates, matching this inset-free GUI.
  local inset=game:GetService('GuiService'):GetGuiInset()
  middle=Input:GetMouseLocation()-Vector2.new(0,inset.Y*.5)
 elseif inputObject and inputObject.UserInputType==Enum.UserInputType.Touch then
  middle=Vector2.new(inputObject.Position.X,inputObject.Position.Y)
 end
 middle-=layer.AbsolutePosition
 for i=1,12 do
  activeParticles+=1
  local a=i*math.pi/6;local length=math.random(45,95);local size=math.random(18,26)
  local p=Instance.new('ImageLabel');p.Name='CoinBurst';p.BackgroundTransparency=1;p.Image=Assets.coin;p.Size=UDim2.fromOffset(size,size);p.Position=UDim2.fromOffset(middle.X,middle.Y);p.ZIndex=55;p.Parent=layer;p.AnchorPoint=Vector2.new(.5,.5);p.Rotation=math.random(0,90)
  local tw=Tween:Create(p,TweenInfo.new(.6,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=UDim2.fromOffset(middle.X+math.cos(a)*length,middle.Y+math.sin(a)*length),Size=UDim2.fromOffset(0,0),ImageTransparency=1,Rotation=p.Rotation+100});tw:Play();tw.Completed:Once(function() p:Destroy();activeParticles-=1 end)
 end
end
local buttonStates={}
local function smooth(b,visual,enabled,withBurst)
 visual=visual or b
 local sc=visual:FindFirstChildOfClass('UIScale') or Instance.new('UIScale');sc.Parent=visual
 local base=sc.Scale;local target;local tween
 local function update()
  local value=base
  if not enabled or enabled() then
   if b.GuiState==Enum.GuiState.Press or os.clock()<(b:GetAttribute('KeyboardPressUntil') or 0) then value=base*.9 elseif b.GuiState==Enum.GuiState.Hover or game:GetService('GuiService').SelectedObject==b then value=base*1.08 end
  end
  if target==value then return end;target=value;if tween then tween:Cancel() end;tween=Tween:Create(sc,TweenInfo.new(.16,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=value});tween:Play()
 end
 b:GetPropertyChangedSignal('GuiState'):Connect(update)
 if withBurst then b.Activated:Connect(function(inputObject) if not enabled or enabled() then burst(b,inputObject) end end) end
 table.insert(buttonStates,{button=b,update=update})
end
local function button(p,n,x,y,w,h,c,label,sub,action,withBurst)
 local f=pixel(p,n,x,y,w,h,c,8)
 f.AnchorPoint=Vector2.new(.5,.5);f.Position=UDim2.fromOffset(x+w/2,y+h/2)
 for _,face in ipairs(f:GetChildren()) do if face.Name:sub(1,4)=='Face' then
  local g=Instance.new('UIGradient');g.Rotation=90;g.Color=ColorSequence.new(c:Lerp(WHITE,.3),c:Lerp(Color3.new(0,0,0),.25));g.Parent=face
 end end
 local gloss=frame(f,'Gloss',14,5,w-28,5,WHITE,10);gloss.BackgroundTransparency=.5
 text(f,label,6,sub and 10 or 0,w-12,sub and 27 or h,sub and 26 or 28,WHITE,11)
 if sub then text(f,sub,6,39,w-12,23,13,Color3.fromRGB(255,224,71),11) end
 local b=Instance.new('TextButton');b.Name=n..'Button';b.Text='';b.BackgroundTransparency=1;b.Size=UDim2.fromScale(1,1);b.AutoButtonColor=false;b.ZIndex=12;b.Parent=f
 smooth(b,f,nil,withBurst);b.Activated:Connect(action);return b
end
local selectedEgg=1
local dismissedEgg=nil
local notice=text(root,'Preview only - placeholder prices and odds',520,668,660,38,24,WHITE,30)
local function previewAction() notice.Text='Hatch preview - no coins spent';end
local panel=pixel(root,'PetOddsPanel',520,110,660,552,Color3.fromRGB(28,57,38),4)
for _,part in ipairs(panel:GetChildren()) do
 part.BackgroundTransparency=.3
 part.BackgroundColor3=part.Name:sub(1,4)=='Face' and Color3.fromRGB(24,51,35) or Color3.fromRGB(23,43,30)
end
local moss=Instance.new('ImageLabel')
moss.Name='MossyGladeBackdrop';moss.BackgroundTransparency=1
moss.Image='rbxassetid://106271266438092';moss.ResampleMode=Enum.ResamplerMode.Pixelated
moss.Position=UDim2.fromOffset(-48,-36);moss.Size=UDim2.fromOffset(756,624)
moss.ScaleType=Enum.ScaleType.Stretch;moss.ImageTransparency=.38;moss.ZIndex=6;moss.Parent=panel
-- Quiet center preserves woodland detail at the outer perimeter.
local calmCenter=frame(panel,'QuietForestCenter',4,72,652,438,Color3.fromRGB(14,34,25),7)
calmCenter.BackgroundTransparency=.04
local calmCorner=Instance.new('UICorner');calmCorner.CornerRadius=UDim.new(0,16);calmCorner.Parent=calmCenter
local backdropCorner=Instance.new('UICorner');backdropCorner.CornerRadius=UDim.new(0,24);backdropCorner.Parent=moss
local backdropBorder=Instance.new('UIStroke');backdropBorder.Name='RoundedBackdropBorder';backdropBorder.Thickness=4;backdropBorder.Transparency=.3;backdropBorder.Color=Color3.fromRGB(123,157,73);backdropBorder.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;backdropBorder.Parent=moss

local function outlinedArcade(label)
 label.Font=Enum.Font.Arcade
 local stroke=label:FindFirstChildOfClass('UIStroke')
 stroke.Color=Color3.fromRGB(5,17,12);stroke.Thickness=3;stroke.LineJoinMode=Enum.LineJoinMode.Round
end
local eggTitle=text(root,'MOSSY EGG',300,-14,1100,130,100,WHITE,8)
outlinedArcade(eggTitle)
local price=pixel(panel,'EggPrice',16,12,174,58,Color3.fromRGB(232,245,249),8)
local coin=Instance.new('ImageLabel');coin.BackgroundTransparency=1;coin.Image=Assets.coin;coin.Size=UDim2.fromOffset(38,38);coin.Position=UDim2.fromOffset(12,10);coin.ZIndex=10;coin.Parent=price
local priceText=text(price,'500',52,0,112,58,30,Color3.fromRGB(255,213,44),10)
local primary=button(root,'PrimaryHatch',205,290,180,154,Color3.fromRGB(132,245,43),Input.TouchEnabled and 'TAP' or 'E',nil,previewAction,true)
local primaryText=primary.Parent:FindFirstChild(Input.TouchEnabled and 'TAP' or 'E');primaryText.TextSize=Input.TouchEnabled and 38 or 80;primaryText.TextColor3=Color3.new(1,1,1)
local promptVisual=primary.Parent
local actionHalo=frame(promptVisual,'ActionHalo',-8,-8,196,170,nil,7)
local haloCorner=Instance.new('UICorner');haloCorner.CornerRadius=UDim.new(0,22);haloCorner.Parent=actionHalo
local actionStroke=Instance.new('UIStroke');actionStroke.Color=Color3.fromRGB(166,255,84);actionStroke.Thickness=5;actionStroke.Transparency=.55;actionStroke.Parent=actionHalo
local actionGloss=frame(promptVisual,'ActionGloss',16,12,148,46,WHITE,10);actionGloss.BackgroundTransparency=.78
local glossFade=Instance.new('UIGradient');glossFade.Rotation=90;glossFade.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)});glossFade.Parent=actionGloss
local promptMotion=frame(root,'ProximityPromptMotion',0,0,134,134,nil,8)
promptMotion.AnchorPoint=promptVisual.AnchorPoint;promptMotion.Position=promptVisual.Position
promptVisual.Parent=promptMotion;promptVisual.Position=UDim2.fromScale(.5,.5)
local proximityScale=Instance.new('UIScale');proximityScale.Name='ProximityPulse';proximityScale.Parent=promptMotion
local promptEnteredAt=0;local promptWasVisible=false;local promptEgg=nil
local hatchLabel=text(root,'Hatch',95,178,400,114,96,WHITE,20)
outlinedArcade(hatchLabel)
hatchLabel.TextColor3=Color3.fromRGB(229,255,184)
button(root,'Close',1130,116,44,44,Color3.fromRGB(220,70,85),'X',nil,function() dismissedEgg=selectedEgg;root.Visible=false end,false)
local keys={'Mosslet','Babacorn','MossbackSnail','Stumpy','GladeFox','SlimePrince','EmberWilfPet','Glimmerhorn'}
local petRarities={'Common','Common','Uncommon','Rare','Epic','Legendary','Legendary','Mythic'}

-- A separate screen-space overlay keeps descriptions readable on narrow phones.
local petNames={Mosslet='Mosslet',Babacorn='Babacorn',MossbackSnail='Mossback Snail',Stumpy='Stumpy',GladeFox='Glade Fox',SlimePrince='Slime Prince',EmberWilfPet='Ember Wilf',Glimmerhorn='Glimmerhorn'}
local function petDescription(key)
 local s=PetCombat.pets[key]
 if not s then return 'This pet has no combat behavior configured yet.' end
 local lines={}
 local function add(line) table.insert(lines,line) end
 if s.guard then add('Shell Guard blocks the next hit you would take. The shell refreshes each room or wave.') end
 if s.damage then
  if s.beam then add(string.format('Fires a piercing beam for %g damage every %g seconds. It hits enemies along the beam.',s.damage,s.every))
  elseif s.dash then add(string.format('Leaf Dash strikes up to %g enemies for %g damage each, with %g seconds between attacks.',s.targets or 1,s.damage,s.every))
  elseif (s.hits or 1)>1 then add(string.format('Fires %g projectiles for %g damage each every %g seconds (%g damage if all hit).',s.hits,s.damage,s.every,s.hits*s.damage))
  else add(string.format('Deals %g damage every %g seconds%s.',s.damage,s.every,(s.targets or 1)>1 and string.format(' to up to %g enemies',s.targets) or '')) end
 end
 if s.bossDamage then add(string.format('Deals +%g bonus damage against bosses (%g damage per hit).',s.bossDamage,(s.damage or 0)+s.bossDamage)) end
 if s.slow then add(string.format('Slows enemies by %g%% for %g seconds.',(1-s.slow.scale)*100,s.slow.duration)) end
 if s.root then add(string.format('Roots its target for %g seconds. Bosses cannot be rooted.',s.root.duration)) end
 if s.burn then add(string.format('Burns targets for %g damage per second for %g seconds.',s.burn.rate,s.burn.duration)) end
 if s.haste then add(string.format('Every %g attacks, grants you +%g%% attack speed for %g seconds.',s.haste.every,s.haste.bonus*100,s.haste.duration)) end
 if s.healPerHit then add(string.format('Restores %g HP to you per enemy hit.',s.healPerHit)) end
 if s.revive then add(string.format('Once per run, saves you from a lethal hit and restores %g%% of your max HP.',s.revive*100)) end
 if s.mark then add(string.format('Marks a target every %g seconds. The target takes %g%% more damage for %g seconds.',s.every,(s.mark.scale-1)*100,s.mark.duration)) end
 if s.heal then add(string.format('Creates a healing patch every %g seconds. Standing in it restores %g HP per second for %g seconds.',s.every,s.heal.perSecond,s.heal.duration)) end
 if s.magnet then add('Pulls nearby-room XP crystals to you.') end
 return table.concat(lines,'\n\n')
end
local details=frame(gui,'PetDetailsOverlay',0,0,0,0,nil,100)
details.Size=UDim2.fromScale(1,1);details.Visible=false
local dim=Instance.new('TextButton');dim.Name='DismissPetDetails';dim.Text='';dim.AutoButtonColor=false;dim.BackgroundColor3=Color3.new(0,0,0);dim.BackgroundTransparency=.38;dim.BorderSizePixel=0;dim.Size=UDim2.fromScale(1,1);dim.ZIndex=1;dim.Parent=details
local detailWindow=pixel(details,'PetDetailsWindow',0,0,560,440,Color3.fromRGB(15,39,29),2)
detailWindow.AnchorPoint=Vector2.new(.5,.5);detailWindow.Position=UDim2.fromScale(.5,.5);detailWindow.Active=true
local detailScale=Instance.new('UIScale');detailScale.Parent=detailWindow
local detailTitle=text(detailWindow,'PetName',28,20,432,46,32,WHITE,5)
detailTitle.TextXAlignment=Enum.TextXAlignment.Left
local detailRarity=text(detailWindow,'PetRarity',28,72,504,30,22,WHITE,5)
detailRarity.TextXAlignment=Enum.TextXAlignment.Left
local detailScroll=Instance.new('ScrollingFrame');detailScroll.Name='DescriptionScroll';detailScroll.BackgroundTransparency=1;detailScroll.BorderSizePixel=0;detailScroll.Position=UDim2.fromOffset(28,118);detailScroll.Size=UDim2.fromOffset(504,248);detailScroll.CanvasSize=UDim2.new();detailScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y;detailScroll.ScrollingDirection=Enum.ScrollingDirection.Y;detailScroll.ScrollBarThickness=5;detailScroll.ScrollBarImageColor3=Color3.fromRGB(169,235,163);detailScroll.ZIndex=5;detailScroll.Parent=detailWindow
local detailBody=text(detailScroll,'PetDescription',0,0,492,0,26,WHITE,6)
detailBody.Size=UDim2.new(1,-12,0,0);detailBody.AutomaticSize=Enum.AutomaticSize.Y;detailBody.TextWrapped=true;detailBody.TextXAlignment=Enum.TextXAlignment.Left;detailBody.TextYAlignment=Enum.TextYAlignment.Top
local hint=text(detailWindow,'Pet info - no purchase made',28,388,504,28,20,Color3.fromRGB(184,214,192),5)
local detailTween
local function closePetDetails()
 if detailTween then detailTween:Cancel();detailTween=nil end
 details.Visible=false
end
local function detailsFit()
 local cam=workspace.CurrentCamera
 if not cam then return 1 end
 return math.max(.1,math.min(1,(cam.ViewportSize.X-28)/560,(cam.ViewportSize.Y-40)/440))
end
local function showPetDetails(key,rarity)
 if not root.Visible then return end
 detailTitle.Text=petNames[key] or key
 detailRarity.Text=rarity:upper()..' PET'
 local color=Rarities.byName[rarity].color
 detailRarity.TextColor3=color
 for _,part in ipairs(detailWindow:GetChildren()) do if part.Name:sub(1,6)=='Border' then part.BackgroundColor3=color end end
 detailBody.Text=petDescription(key)
 details:SetAttribute('PetKey',key);detailScroll.CanvasPosition=Vector2.zero
 if detailTween then detailTween:Cancel() end
 details.Visible=true;local fit=detailsFit();detailScale.Scale=fit*.9
 detailTween=Tween:Create(detailScale,TweenInfo.new(.2,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=fit});detailTween:Play()
end
dim.Activated:Connect(closePetDetails)
button(detailWindow,'ClosePetDetails',484,18,48,48,Color3.fromRGB(220,70,85),'X',nil,closePetDetails,false)
root:GetPropertyChangedSignal('Visible'):Connect(function() if not root.Visible then closePetDetails() end end)
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal('ViewportSize'):Connect(function()
 if detailTween then detailTween:Cancel();detailTween=nil end
 detailScale.Scale=detailsFit()
end) end

local cells={};local spinning={};local gleams={}
local brightRarity={Common=Color3.fromRGB(216,224,232),Uncommon=Color3.fromRGB(70,255,113),Rare=Color3.fromRGB(0,228,255),Epic=Color3.fromRGB(195,83,255),Legendary=Color3.fromRGB(255,211,28),Mythic=Color3.fromRGB(255,40,101)}
for i=1,#keys do
 local slot=frame(panel,'PetSlot'..i,16+((i-1)%4)*162,96+math.floor((i-1)/4)*200,204,212,nil,8)
 local slotScale=Instance.new('UIScale');slotScale.Scale=.75;slotScale.Parent=slot
 local card=pixel(slot,'PetCard'..i,0,0,204,212,Color3.fromRGB(0,195,239),8)
 card.AnchorPoint=Vector2.new(.5,.5);card.Position=UDim2.fromOffset(102,106)
 local glow={}
 for layer=1,3 do
  local spread=({7,4,2})[layer]
  local g=frame(slot,'RarityGlow'..i..'Layer'..layer,-spread,-spread,204+spread*2,212+spread*2,nil,7)
  g.Visible=false
  local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,12+spread);corner.Parent=g
  local stroke=Instance.new('UIStroke');stroke.Name='SolidHalo';stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;stroke.LineJoinMode=Enum.LineJoinMode.Round
  stroke.Thickness=({12,8,4})[layer];stroke.Transparency=({.9,.7,.25})[layer];stroke.Parent=g
  local rotation=Instance.new('UIGradient');rotation.Name='GlowRotation'
  rotation.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.95),NumberSequenceKeypoint.new(.45,.8),NumberSequenceKeypoint.new(.75,.25),NumberSequenceKeypoint.new(1,0)})
  rotation.Parent=stroke
  table.insert(glow,g)
 end
 local rarity=petRarities[i];card:SetAttribute('Rarity',rarity);card:SetAttribute('PetKey',keys[i])
 for _,face in ipairs(card:GetChildren()) do if face.Name:sub(1,4)=='Face' then face.BackgroundColor3=Rarities.byName[rarity].color end end
 local texture=frame(card,'PixelRarityBackground',6,12,192,188,nil,9)
 local tiles={}
 for row=0,7 do for col=0,7 do
  local hash=(col*17+row*31+math.floor(col/2)*13+math.floor(row/2)*7)%11
  local shade=(hash-5)*.006+(3.5-row)*.004
  local tile=frame(texture,'PixelTile',col*24,row*24,24,math.min(24,188-row*24),WHITE,9)
  table.insert(tiles,{frame=tile,shade=shade})
 end end
 local clip=frame(card,'IconClip',6,6,192,194,nil,11);clip.ClipsDescendants=true local fx=frame(clip,'MythicPlusSpin',0,0,192,194,nil,11);fx.Visible=false
 local pluses={}
 for j=1,18 do
  local size=9+(j%4)*2;local thickness=2
  local plus=frame(fx,'RainbowPlus',0,0,size,size,nil,11);plus.AnchorPoint=Vector2.new(.5,.5)
  local x=((j*.61803398875)%1)*.9+.05;local phase=(j*.381966)%1
  plus.Position=UDim2.fromScale(x,phase)
  local a=frame(plus,'Horizontal',0,(size-thickness)/2,size,thickness,WHITE,11)
  local b=frame(plus,'Vertical',(size-thickness)/2,0,thickness,size,WHITE,11)
  a.BackgroundTransparency=.72;b.BackgroundTransparency=.72
  table.insert(pluses,{root=plus,a=a,b=b,phase=phase,x=x,speed=.12+(j%4)*.025})
 end
 table.insert(spinning,{frame=fx,pluses=pluses})
 local viewport=Instance.new('ViewportFrame');viewport.Name='PetModel';viewport.BackgroundTransparency=1;viewport.Size=UDim2.fromScale(1,1);viewport.ZIndex=12;viewport.Ambient=Color3.fromRGB(220,220,220);viewport.LightColor=WHITE;viewport.LightDirection=Vector3.new(-1,-1,-2);viewport.Parent=clip
 local shine=frame(card,'WholeCardGleam',0,0,204,212,nil,10);shine.ClipsDescendants=true
 local strips={};local q=6;local w,h=204,212
 for j=1,math.ceil(h/3) do
  local y=(j-1)*3;local inset=(y<q or y>=h-q) and q*2 or ((y<q*2 or y>=h-q*2) and q or 0)
  local r={inset,y,w-inset*2,math.min(3,h-y)}
  local band=frame(shine,'CardShine'..j,r[1],r[2],r[3],r[4],WHITE,10)
  local g=Instance.new('UIGradient');g.Name='CardGleamGradient'
  g.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.36,1),NumberSequenceKeypoint.new(.444,.85),NumberSequenceKeypoint.new(.5,.65),NumberSequenceKeypoint.new(.556,.85),NumberSequenceKeypoint.new(.64,1),NumberSequenceKeypoint.new(1,1)})
  g.Offset=Vector2.new(-1.5,0);g.Parent=band;table.insert(strips,{gradient=g,x=r[1],y=r[2]+r[4]/2,width=r[3]})
 end
 table.insert(gleams,{frame=shine,phase=(i-1)*.22,strips=strips})
 local name=text(card,'PET',4,147,196,33,24,WHITE,16);name.Visible=false
 local odds=text(card,'—%',6,157,188,49,42,Color3.new(1,1,1),32);odds.TextXAlignment=Enum.TextXAlignment.Right;odds.Font=Enum.Font.FredokaOne
 local oddsStroke=odds:FindFirstChildOfClass('UIStroke');oddsStroke.Thickness=4;oddsStroke.Color=INK;oddsStroke.LineJoinMode=Enum.LineJoinMode.Round
 local oddsGleam=Instance.new('UIGradient');oddsGleam.Name='MythicPercentageGleam';oddsGleam.Rotation=15;oddsGleam.Enabled=false
 oddsGleam.Color=ColorSequence.new({
  ColorSequenceKeypoint.new(0,Color3.new(1,1,1)),ColorSequenceKeypoint.new(.25,Color3.new(1,1,1)),
  ColorSequenceKeypoint.new(.34,Color3.fromRGB(255,110,165)),ColorSequenceKeypoint.new(.42,Color3.fromRGB(255,215,90)),
  ColorSequenceKeypoint.new(.5,Color3.fromRGB(100,255,155)),ColorSequenceKeypoint.new(.58,Color3.fromRGB(95,205,255)),
  ColorSequenceKeypoint.new(.66,Color3.fromRGB(205,130,255)),ColorSequenceKeypoint.new(.75,Color3.new(1,1,1)),ColorSequenceKeypoint.new(1,Color3.new(1,1,1))})
 oddsGleam.Parent=odds
 local inspect=Instance.new('TextButton');inspect.Name='InspectPet';inspect.Text='';inspect.BackgroundTransparency=1;inspect.Size=UDim2.fromScale(1,1);inspect.AutoButtonColor=false;inspect.Selectable=true;inspect.ZIndex=50;inspect.Parent=card
 inspect:SetAttribute('PetKey',keys[i]);inspect:SetAttribute('Rarity',petRarities[i])
 smooth(inspect,card,function() return root.Visible and not details.Visible end,false)
 inspect.Activated:Connect(function() showPetDetails(card:GetAttribute('PetKey'),card:GetAttribute('Rarity')) end)
 inspect.MouseEnter:Connect(function() slot.ZIndex=15 end)
 inspect.MouseLeave:Connect(function() slot.ZIndex=8 end)
 cells[i]={card=card,viewport=viewport,spin=fx,name=name,odds=odds,glow=glow,oddsGleam=oddsGleam,tiles=tiles,inspect=inspect}
end
local placeholderOdds={40,30,15,8,4,2,.9,.1}
local function populate()
 priceText.Text='500'
 moss.Image='rbxassetid://106271266438092'
 backdropBorder.Color=Color3.fromRGB(123,157,73)
 local models=RS:FindFirstChild('HatcheryPetIcons')
 for i,cell in ipairs(cells) do
  local index=i;local key=keys[index];local rarity=petRarities[index]
  local display=key:gsub('(%l)(%u)','%1 %2'):gsub('Wilf Pet','Wilf')
  cell.odds.Text=tostring(placeholderOdds[index])..'%'
  cell.name.Text=display;cell.spin.Visible=rarity=='Mythic'
  cell.oddsGleam.Enabled=rarity=='Mythic'
  local silhouette=rarity=='Mythic'
  cell.viewport.ImageColor3=silhouette and Color3.new(0,0,0) or Color3.new(1,1,1)
  cell.viewport:SetAttribute('Silhouette',silhouette)
  cell.card:SetAttribute('PetKey',key);cell.card:SetAttribute('Rarity',rarity)
  for _,face in ipairs(cell.card:GetChildren()) do if face.Name:sub(1,4)=='Face' then face.BackgroundColor3=brightRarity[rarity] or Rarities.byName[rarity].color end end  local base=brightRarity[rarity] or Rarities.byName[rarity].color
  for _,tile in ipairs(cell.tiles) do
   tile.frame.BackgroundColor3=base:Lerp(tile.shade>=0 and Color3.new(1,1,1) or Color3.new(0,0,0),math.abs(tile.shade))
  end
  for _,g in ipairs(cell.glow) do g.Visible=rarity=='Epic' or rarity=='Legendary' or rarity=='Mythic' end
  if cell.viewport:GetAttribute('LoadedPet')==key and cell.viewport:FindFirstChildOfClass('WorldModel') then continue end
  cell.viewport:ClearAllChildren()
  local source=models and models:FindFirstChild(key)
  if source then
   local world=Instance.new('WorldModel');world.Parent=cell.viewport;local m=source:Clone();m.Parent=world
   local cf,size=m:GetBoundingBox();local center=cf.Position
   local camera=Instance.new('Camera');camera.FieldOfView=35
   local direction=Vector3.new(.38,.2,-1).Unit
   local basis=CFrame.lookAt(center+direction,center)
   local occupancy=(key=='GladeFox' or key=='EmberWilfPet') and .91 or .83
   local tanY=math.tan(math.rad(camera.FieldOfView*.5))*occupancy
   local tanX=tanY*(192/194)
   local distance=0
   for _,x in ipairs({-1,1}) do for _,y in ipairs({-1,1}) do for _,z in ipairs({-1,1}) do
    local corner=cf:PointToWorldSpace(Vector3.new(size.X*x/2,size.Y*y/2,size.Z*z/2))
    local q=basis:VectorToObjectSpace(corner-center)
    distance=math.max(distance,q.Z+math.abs(q.X)/tanX,q.Z+math.abs(q.Y)/tanY)
   end end end
   camera.CFrame=CFrame.lookAt(center+direction*(distance+.05),center)   if key=='GladeFox' or key=='EmberWilfPet' then
    -- Center the projected silhouette bounds, including perspective asymmetry.
    for pass=1,4 do
     local minX,maxX,minY,maxY=math.huge,-math.huge,math.huge,-math.huge
     for _,x in ipairs({-1,1}) do for _,y in ipairs({-1,1}) do for _,z in ipairs({-1,1}) do
      local q=camera.CFrame:PointToObjectSpace(cf:PointToWorldSpace(Vector3.new(size.X*x/2,size.Y*y/2,size.Z*z/2)))
      local px,py=q.X/-q.Z,q.Y/-q.Z
      minX=math.min(minX,px);maxX=math.max(maxX,px);minY=math.min(minY,py);maxY=math.max(maxY,py)
     end end end
     local shift=camera.CFrame.RightVector*((minX+maxX)*.5*(distance+.05))+camera.CFrame.UpVector*((minY+maxY)*.5*(distance+.05))
     camera.CFrame=camera.CFrame+shift
    end
   end
   camera.Parent=cell.viewport;cell.viewport.CurrentCamera=camera;cell.viewport:SetAttribute('LoadedPet',key)
   cell.viewport:SetAttribute('FitOccupancy',occupancy)


  end
 end
end
text(panel,'8 PETS - PREVIEW ODDS',16,516,628,28,22,WHITE,12)
populate()
task.spawn(function() pcall(function() game:GetService('ContentProvider'):PreloadAsync({panel}) end) end)
task.spawn(function() local folder=RS:WaitForChild('HatcheryPetIcons',30);if folder then folder.ChildAdded:Connect(function() if root.Visible then populate() end end) end end)
local station
for _,s in ipairs(Lobby.stations) do if s.piece=='EggHatchery' then station=Lobby.origin+Vector3.new(s.at.X,0,s.at.Y) end end
local function nearbyEgg()
 local char=player.Character;local hrp=char and char:FindFirstChild('HumanoidRootPart')
 if not station or not hrp or workspace:GetAttribute('InLobby')~=true or pg:FindFirstChild('StoryCutscene') or pg:FindFirstChild('IntroCutscene') then return nil end
 local pos=Vector3.new(hrp.Position.X,0,hrp.Position.Z)
 local left=station+Vector3.new(-9,0,10);local right=station+Vector3.new(9,0,10)
 local dl,dr=(pos-left).Magnitude,(pos-right).Magnitude
 if math.min(dl,dr)>17 then return nil end
 return 1
end
Input.InputBegan:Connect(function(key,processed)
 if details.Visible then
  if key.KeyCode==Enum.KeyCode.Escape then closePetDetails() end
  return
 end
 if processed then return end
 if key.KeyCode==Enum.KeyCode.E and nearbyEgg() then
  primary:SetAttribute('KeyboardPressUntil',os.clock()+.16)
  if dismissedEgg then dismissedEgg=nil;root.Visible=true else burst(primary);previewAction() end
 elseif key.KeyCode==Enum.KeyCode.Escape then dismissedEgg=selectedEgg;root.Visible=false end
end)

local managed=setmetatable({},{__mode='k'})
local function bindOtherButton(b)
 if not b:IsA('GuiButton') or b:IsDescendantOf(gui) or managed[b] then return end;managed[b]=true
 local p=b.Parent;local visual=b
 if p:IsA('Frame') and (p.Name=='Button' or p.Name:sub(1,3)=='Tab') then visual=p end
 local function enabled() return b.Active and b:GetAttribute('UIEffectsEnabled')~=false end
 smooth(b,visual,enabled,false)
 b.Activated:Connect(function()
  local label=b:IsA('TextButton') and b.Text or ''
  if label=='' then for _,c in ipairs(p:GetChildren()) do if c:IsA('TextLabel') then label=c.Text;break end end end
  if enabled() and (label:upper():find('BUY') or label:upper():find('HATCH')) then burst(b) end
 end)
 visual:SetAttribute('FXManagedScale',true)
end
for _,n in ipairs(pg:GetDescendants()) do bindOtherButton(n) end
pg.DescendantAdded:Connect(bindOtherButton)
local elapsed=0
Run.RenderStepped:Connect(function(dt)
 elapsed+=dt
 local nearby=nearbyEgg()
 if not nearby then root.Visible=false;dismissedEgg=nil
 else
  if nearby~=selectedEgg then
   selectedEgg=nearby;dismissedEgg=nil;eggTitle.Text='MOSSY EGG'
   notice.Text='Preview only - placeholder prices and odds';populate()
  end
  root.Visible=dismissedEgg~=nearby
 end
 for i=#buttonStates,1,-1 do local v=buttonStates[i];if not v.button.Parent then table.remove(buttonStates,i) else v.update() end end
 local showing=root.Visible
 if showing and (not promptWasVisible or promptEgg~=selectedEgg) then promptEnteredAt=os.clock();promptEgg=selectedEgg end
 promptWasVisible=showing
 if not showing then return end
 for _,cell in ipairs(cells) do
  if cell.oddsGleam.Enabled then
   -- Periodic rainbow colors travel continuously at half the previous sweep speed.
   cell.oddsGleam.Offset=Vector2.zero
   local colors={}
   for j=0,12 do
    table.insert(colors,ColorSequenceKeypoint.new(j/12,Color3.fromHSV((j/12-elapsed/4.4)%1,.6,1)))
   end
   cell.oddsGleam.Color=ColorSequence.new(colors)
  end
 end
 for i,cell in ipairs(cells) do
  local rarity=cell.card:GetAttribute('Rarity')
  if rarity=='Epic' or rarity=='Legendary' or rarity=='Mythic' then
   local color=rarity=='Mythic' and Color3.fromHSV((elapsed*.12)%1,.75,1) or (rarity=='Epic' and Color3.fromRGB(192,100,255) or Color3.fromRGB(255,205,55))
   local pulse=(math.sin(elapsed*1.4+i*.4)+1)*.5
   for layer,g in ipairs(cell.glow) do
    local stroke=g.SolidHalo
    stroke.Color=color
    stroke.Transparency=({.88,.65,.18})[layer]
    stroke.GlowRotation.Rotation=(elapsed*60-90)%360
   end
  end
 end
 actionStroke.Transparency=.5+.15*math.sin(elapsed*2.2)
 local age=os.clock()-promptEnteredAt
 if age<.38 then
  proximityScale.Scale=.65+.35*Tween:GetValue(math.clamp(age/.38,0,1),Enum.EasingStyle.Back,Enum.EasingDirection.Out)
 else
  local pressing=primary.GuiState==Enum.GuiState.Press or os.clock()<(primary:GetAttribute('KeyboardPressUntil') or 0)
  proximityScale.Scale=pressing and 1 or 1+.045*math.sin((age-.38)*math.pi*1.5)
 end
 for _,g in ipairs(gleams) do
  local cycle=(elapsed+g.phase)%8.6;local center=-.25+(cycle/6)*1.5
  g.frame.Visible=cycle<6
  if cycle<6 then for _,strip in ipairs(g.strips) do
   strip.gradient.Offset=Vector2.new((center*204+(strip.y-106)*.45-strip.x)/strip.width-.5,0)
  end end
 end
 for _,spin in ipairs(spinning) do if spin.frame.Visible then for _,p in ipairs(spin.pluses) do p.root.Position=UDim2.fromScale(p.x,-.12+((elapsed*p.speed+p.phase)%1)*1.24);p.root.Rotation=0;local c=Color3.fromHSV((elapsed*.15+p.phase)%1,.8,1);p.a.BackgroundColor3=c;p.b.BackgroundColor3=c end end end
end)


