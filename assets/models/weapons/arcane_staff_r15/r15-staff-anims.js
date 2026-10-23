// Arcane Staff — R15 animations (Hold, Charge, Channel, Cast) + Roblox scripts.
import { solveArm, JOINTS } from './r15-bow-anims.js';

export const STAFF_SCALE = 3.4;                               // studs per staff-model unit
export const STAFF_GRIP = { pos: [0, -0.1, 0], rotX: -Math.PI / 2 }; // RightHand -> staff origin
export const KIT = { kit: 'ArcaneStaffKit', folder: 'ArcaneStaffAnimations', prefix: 'Staff_', server: 'ArcaneStaffEquip', client: 'ArcaneStaffAnimator' };
const ARMS = ['LeftShoulder', 'LeftElbow', 'LeftWrist', 'RightShoulder', 'RightElbow', 'RightWrist'];
const ALL = JOINTS.map(j => j[0]);
const D2R = Math.PI / 180;

export function bakeStaffAnimations(THREE, rig) {
  const V = THREE.Vector3, J = rig.joints;
  const W = o => o.getWorldPosition(new V());
  const rotQ = spec => { const q = new THREE.Quaternion(); for (const [ax, deg] of spec || []) q.multiply(new THREE.Quaternion().setFromAxisAngle(new V(ax === 'X' ? 1 : 0, ax === 'Y' ? 1 : 0, ax === 'Z' ? 1 : 0), deg * D2R)); return q; };
  const reset = () => { for (const j of ALL) J[j].quaternion.identity(); J.Root.position.copy(J.Root.userData.c0); rig.root.updateMatrixWorld(true); };
  const setBody = body => { reset(); for (const [j, v] of Object.entries(body)) { if (v.r) J[j].quaternion.copy(rotQ(v.r)); if (v.p) J[j].position.copy(J[j].userData.c0).add(new V(...v.p)); } rig.root.updateMatrixWorld(true); };
  // staff up = hand -Z, staff forward = hand -Y
  const staff = up => { up = new V(...up).normalize(); const fwd = new V(0, 0, -1).addScaledVector(up, up.z).normalize(); return { up, fwd }; };
  const stance = (k = 1, lean = 0) => ({
    Root: { r: [['Y', 12 * k]], p: [0, -0.08 * k, 0] }, Waist: { r: [['Y', -8 * k], ['X', -lean]] }, Neck: { r: [['Y', -4 * k], ['X', lean * 0.5]] },
    LeftHip: { r: [['X', 14 * k], ['Z', -6 * k]] }, LeftKnee: { r: [['X', -12 * k]] }, LeftAnkle: { r: [['X', 2 * k]] },
    RightHip: { r: [['X', -10 * k], ['Z', 6 * k]] }, RightKnee: { r: [['X', -12 * k]] }, RightAnkle: { r: [['X', 6 * k]] },
  });
  const ORB_UP = 0.643 * STAFF_SCALE; // grip -> orb centre, studs
  const hold = bob => ({ body: {}, R: { rel: [0.25, -1.25 + bob, -0.55], ...staff([0.12, 1, -0.18]), elbowRel: [0.45, -0.75, 0.25] }, L: { relL: [-0.2, -1.85 + bob * 0.5, 0.1] } });
  const raised = (dy = 0, sway = 0) => {
    const s = staff([0.05, 1, -0.55]);
    return { body: stance(), R: { rel: [0.2, -0.55 + dy, -1.0], ...s, elbowRel: [0.55, -0.55, -0.2] },
      L: { relL: [0.8 + sway, -0.45 + dy, -1.2] } };
  };
  const defs = {
    Hold: { loop: true, priority: 2, joints: ARMS, keys: [{ t: 0, ...hold(0) }, { t: 1.2, ...hold(0.04) }, { t: 2.4, ...hold(0) }] },
    Charge: { loop: false, priority: 3, joints: ALL, keys: [
      { t: 0, ...hold(0), body: stance(0.3) },
      { t: 0.22, ...raised(0.12) },
      { t: 0.5, ...raised(0) }] },
    Channel: { loop: true, priority: 3, joints: ALL, keys: [{ t: 0, ...raised(0) }, { t: 0.6, ...raised(0.05, 0.06) }, { t: 1.2, ...raised(0) }] },
    Cast: { loop: false, priority: 3, joints: ALL, keys: [
      { t: 0, ...raised(0) },
      { t: 0.08, body: stance(1, 9), R: { rel: [0.15, -0.5, -1.45], ...staff([0, 1, -1.05]), elbowRel: [0.5, -0.4, -0.6] }, L: { relL: [0.4, -0.2, -1.55] }, marker: 'Cast' },
      { t: 0.2, body: stance(1, 6), R: { rel: [0.17, -0.55, -1.3], ...staff([0, 1, -0.85]), elbowRel: [0.5, -0.45, -0.45] }, L: { relL: [0.3, -0.4, -1.3] } },
      { t: 0.45, ...hold(0), body: stance(0.4) }] },
  };
  const out = {}; let lastL = null, lastR = null; const errs = [];
  for (const [name, def] of Object.entries(defs)) {
    const keys = [];
    for (const k of def.keys) {
      setBody(k.body);
      const RS = W(J.RightShoulder), LS = W(J.LeftShoulder), off = new V(...STAFF_GRIP.pos);
      const gR = { hand: RS.clone().add(new V(...k.R.rel)), fwd: k.R.fwd, up: k.R.up, off, elbow: k.R.elbowRel ? RS.clone().add(new V(...k.R.elbowRel)) : null };
      const sR = solveArm(THREE, rig, 'R', gR, lastR); lastR = sR.p;
      let gL;
      if (k.L.relL) gL = { hand: LS.clone().add(new V(...k.L.relL)), off: new V(0, -0.1, 0) };
      else gL = { hand: gR.hand.clone().addScaledVector(k.R.up, ORB_UP * k.L.along * 0.5).add(new V(...k.L.fromR)), off: new V(0, -0.1, 0), elbow: LS.clone().add(new V(-0.5, -0.6, -0.3)) };
      const sL = solveArm(THREE, rig, 'L', gL, lastL); lastL = sL.p;
      errs.push([name, k.t, +sL.err.toFixed(3), +sR.err.toFixed(3)]);
      const rot = {}, pos = {};
      for (const j of def.joints) rot[j] = J[j].quaternion.clone();
      if (def.joints.includes('Root')) pos.Root = J.Root.position.clone().sub(J.Root.userData.c0);
      keys.push({ t: k.t, rot, pos, marker: k.marker });
    }
    out[name] = { name, loop: def.loop, priority: def.priority, joints: def.joints, keys, length: def.keys[def.keys.length - 1].t };
  }
  reset();
  return { anims: out, errs };
}

const f = x => (Math.abs(x) < 1e-7 ? 0 : x).toFixed(6);
const v3 = v => `Vector3.new(${f(v.x)}, ${f(v.y)}, ${f(v.z)})`;
export function staffLuau(c) {
  const server = `-- ArcaneStaffEquip  (Script → StarterPlayer > StarterCharacterScripts)
-- Clones ReplicatedStorage.ArcaneStaff, scales it for an R15 character and welds it to the RightHand.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local STAFF_HEIGHT = ${f(c.staffHeight)}     -- studs, spike tip to top orbit orb
local MODEL_HEIGHT = ${f(c.modelHeight)}     -- same, in model units (as exported)
local SHAFT_CENTER = ${v3(c.shaftCenter)}    -- Shaft mesh centre in model units

local character = script.Parent
local rightHand = character:WaitForChild("RightHand")

local staff = ReplicatedStorage:WaitForChild("ArcaneStaff"):Clone()
staff.Name = "ArcaneStaff"
staff:ScaleTo(staff:GetScale() * STAFF_HEIGHT / staff:GetExtentsSize().Y)
local S = STAFF_HEIGHT / MODEL_HEIGHT

local shaft = staff:FindFirstChild("Shaft", true)
local orb = staff:FindFirstChild("Orb", true)
assert(shaft and orb, "ArcaneStaff needs parts named Shaft and Orb")
for _, p in staff:GetDescendants() do
	if p:IsA("BasePart") then
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		if p.Name:match("^Orbit_Orb_") then
			-- Weld (not WeldConstraint) so the client can spin it by changing C0
			local w = Instance.new("Weld")
			w.Name = "OrbitWeld"
			w.Part0 = orb
			w.Part1 = p
			w.C0 = orb.CFrame:ToObjectSpace(p.CFrame)
			w.Parent = p
		elseif p ~= shaft then
			local wc = Instance.new("WeldConstraint")
			wc.Part0 = shaft
			wc.Part1 = p
			wc.Parent = p
		end
	end
end

local origin = Instance.new("Attachment")
origin.Name = "StaffOrigin"            -- staff model origin: grip point, -Z = casting direction
origin.CFrame = CFrame.new(-SHAFT_CENTER * S)
origin.Parent = shaft
staff:SetAttribute("StudsPerUnit", S)

local weld = Instance.new("Weld")
weld.Name = "StaffGrip"
weld.Part0 = rightHand
weld.Part1 = shaft
weld.C0 = CFrame.new(${STAFF_GRIP.pos.join(', ')}) * CFrame.Angles(-math.pi / 2, 0, 0)
weld.C1 = CFrame.new(-SHAFT_CENTER * S)
weld.Parent = shaft
staff.Parent = character
`;
  const client = `-- ArcaneStaffAnimator  (LocalScript → StarterPlayer > StarterCharacterScripts)
-- Plays the staff animations, charges the orb (spin, swell, glow) and casts bolts.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

-- Paste published animation ids here (rbxassetid://...). Leave "" to use the
-- KeyframeSequences in ReplicatedStorage.ArcaneStaffAnimations (Studio play-testing only).
local ANIM_IDS = { Hold = "", Charge = "", Channel = "", Cast = "" }

local AUTO_CAST = true      -- Archero style: keep casting while standing still
local CHANNEL_TIME = 0.15   -- seconds fully charged before an auto release
local BOLT_SPEED = 55       -- studs per second
local BOLT_RANGE = 70       -- studs
local function hasTarget()  -- replace with your own "is an enemy alive?" check
	return true
end
local function onCast(origin: Vector3, direction: Vector3, power: number)
	-- Fire a RemoteEvent here so the server can spawn the real projectile and apply damage.
end

local ORBIT_AXIS = ${v3(c.orbitAxis)}   -- orbit ring axis in Orb space
local GLOW = Color3.fromRGB(80, 170, 255)

local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")
local animator = humanoid:WaitForChild("Animator")
local root = character:WaitForChild("HumanoidRootPart")
local staff = character:WaitForChild("ArcaneStaff")
local orb = staff:FindFirstChild("Orb", true)
local S = staff:GetAttribute("StudsPerUnit")
while not S do
	staff:GetAttributeChangedSignal("StudsPerUnit"):Wait()
	S = staff:GetAttribute("StudsPerUnit")
end

-- animations
local folder = ReplicatedStorage:FindFirstChild("ArcaneStaffAnimations")
local function loadTrack(name)
	local id = ANIM_IDS[name]
	if id == "" then
		local kfs = folder and folder:FindFirstChild("Staff_" .. name)
		assert(kfs, "No animation id or KeyframeSequence for " .. name)
		id = game:GetService("KeyframeSequenceProvider"):RegisterKeyframeSequence(kfs)
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	return animator:LoadAnimation(anim)
end
local tracks = {}
for _, name in { "Hold", "Charge", "Channel", "Cast" } do
	tracks[name] = loadTrack(name)
end
tracks.Hold.Priority = Enum.AnimationPriority.Action
tracks.Hold.Looped = true
tracks.Channel.Looped = true
for _, name in { "Charge", "Channel", "Cast" } do
	tracks[name].Priority = Enum.AnimationPriority.Action2
end
tracks.Hold:Play(0.2)

-- orb glow + orbit
local orbBase = orb.Size
local light = Instance.new("PointLight")
light.Color = GLOW
light.Range = 8
light.Brightness = 1
light.Shadows = false
light.Parent = orb
local orbits = {}
for i = 1, 3 do
	local p = staff:FindFirstChild("Orbit_Orb_" .. i, true)
	local w = p and p:FindFirstChild("OrbitWeld")
	if w then table.insert(orbits, { weld = w, offset = w.C0.Position }) end
end

-- bolt
local boltTemplate = ReplicatedStorage:WaitForChild("ArcaneBolt")
local function launch(power)
	local b = boltTemplate:Clone()
	for _, p in b:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Material = Enum.Material.Neon
		end
	end
	local diameter = 0.1 * S * (0.55 + 0.6 * power)
	b:ScaleTo(b:GetScale() * diameter / b:GetExtentsSize().X)
	local core = b:FindFirstChildWhichIsA("BasePart", true)
	local pl = Instance.new("PointLight")
	pl.Color = GLOW
	pl.Range = 10
	pl.Brightness = 3
	pl.Parent = core
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position = Vector3.new(0, diameter * 0.35, 0)
	a1.Position = Vector3.new(0, -diameter * 0.35, 0)
	a0.Parent, a1.Parent = core, core
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Color = ColorSequence.new(Color3.fromRGB(170, 235, 255), GLOW)
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Lifetime = 0.18
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Parent = core

	local dir = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	dir = dir.Magnitude > 0 and dir.Unit or Vector3.new(0, 0, -1)
	local start = orb.Position
	b:PivotTo(CFrame.lookAt(start, start + dir))
	b.Parent = workspace
	onCast(start, dir, power)
	local travelled, conn = 0, nil
	conn = RunService.Heartbeat:Connect(function(dt)
		local step = BOLT_SPEED * dt
		travelled += step
		b:PivotTo(b:GetPivot() + dir * step)
		if travelled >= BOLT_RANGE then
			conn:Disconnect()
			b:Destroy()
		end
	end)
end

-- state machine: idle → charging → channeling → casting → idle
local state, charge, chargeStart, grow, spin = "idle", 0, 0, 1, 0

tracks.Charge.Stopped:Connect(function()
	if state == "charging" then
		state = "channeling"
		tracks.Channel:Play(0.05)
	end
end)
tracks.Cast:GetMarkerReachedSignal("Cast"):Connect(function()
	launch(charge)
	charge, grow = 0, 0.45
end)
tracks.Cast.Stopped:Connect(function()
	if state == "casting" then state = "idle" end
end)

local function startCharge()
	if state ~= "idle" then return end
	state, chargeStart = "charging", os.clock()
	tracks.Cast:Stop(0.1)
	tracks.Charge:Play(0.12)
end
local function release()
	if state == "charging" and os.clock() - chargeStart < 0.15 then
		state, charge = "idle", 0
		tracks.Charge:Stop(0.15)
		return
	end
	if state ~= "charging" and state ~= "channeling" then return end
	state = "casting"
	tracks.Charge:Stop(0.05)
	tracks.Channel:Stop(0.05)
	tracks.Cast:Play(0.03)
end
local function cancel()
	if state == "charging" or state == "channeling" then
		state, charge = "idle", 0
		tracks.Charge:Stop(0.15)
		tracks.Channel:Stop(0.15)
	end
end

if AUTO_CAST then
	local fullAt = nil
	RunService.Heartbeat:Connect(function()
		if humanoid.MoveDirection.Magnitude > 0.05 or not hasTarget() then
			cancel()
			fullAt = nil
		elseif state == "idle" then
			startCharge()
		elseif state == "channeling" and charge >= 1 then
			fullAt = fullAt or os.clock()
			if os.clock() - fullAt >= CHANNEL_TIME then
				fullAt = nil
				release()
			end
		end
	end)
else
	ContextActionService:BindAction("ArcaneStaffCast", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			startCharge()
		elseif inputState == Enum.UserInputState.End then
			release()
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
end

local render = RunService.RenderStepped:Connect(function(dt)
	if state == "charging" or state == "channeling" then
		charge = math.min(1, charge + dt / 0.7)
	end
	grow = math.min(1, grow + dt * 1.6)
	local c = 1 - (1 - charge) ^ 2
	spin += dt * (0.9 + 7 * c)
	local rot = CFrame.fromAxisAngle(ORBIT_AXIS, spin)
	for _, o in orbits do
		o.weld.C0 = CFrame.new(rot:VectorToWorldSpace(o.offset * (1 - 0.22 * c)))
	end
	local pulse = 1 + 0.08 * c * math.sin(os.clock() * 30)
	orb.Size = orbBase * (grow * (1 + 0.12 * c) * pulse)
	light.Brightness = 1 + 4 * c
	light.Range = 8 + 6 * c
end)

humanoid.Died:Connect(function()
	render:Disconnect()
end)
`;
  return { server, client };
}
