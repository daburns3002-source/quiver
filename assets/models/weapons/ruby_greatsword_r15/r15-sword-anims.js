// Ruby Greatsword — two-handed R15 animations (shoulder Hold + 3-hit heavy combo) + Roblox scripts.
import { solveArm, JOINTS } from './r15-bow-anims.js';

export const SWORD_SCALE = 4.0;   // studs per sword-model unit (greatsword ≈ 5 studs)
// RightHand holds the upper grip, LeftHand the lower grip. Blade up = hand -Z, edge forward = hand -Y.
export const SWORD_GRIP = { pos: [0, -0.1, 0] };
export const GRIP_UPPER = 0.062, GRIP_LOWER = -0.07;
export const DRAG_LEN = (1.0216 - 0.062) * 4.0;   // studs from right-hand grip to blade tip   // model-unit Y of each hand on the grip
export function gripMatrix(THREE) {
  const q = gripQuat(THREE), p = new THREE.Vector3(...SWORD_GRIP.pos).sub(new THREE.Vector3(0, GRIP_UPPER * SWORD_SCALE, 0).applyQuaternion(q));
  return new THREE.Matrix4().compose(p, q, new THREE.Vector3(SWORD_SCALE, SWORD_SCALE, SWORD_SCALE));
}
export const KIT = { kit: 'RubySwordKit', folder: 'RubySwordAnimations', prefix: 'Sword_', server: 'RubySwordEquip', client: 'RubySwordAnimator' };
const ARMS = ['LeftShoulder', 'LeftElbow', 'LeftWrist', 'RightShoulder', 'RightElbow', 'RightWrist'];
const ALL = JOINTS.map(j => j[0]);
const D2R = Math.PI / 180;

export function gripQuat(THREE) {
  return new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(1, 0, 0), -Math.PI / 2).multiply(new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0, 1, 0), Math.PI / 2));
}

export function bakeSwordAnimations(THREE, rig) {
  const V = THREE.Vector3, J = rig.joints;
  const W = o => o.getWorldPosition(new V());
  const rotQ = spec => { const q = new THREE.Quaternion(); for (const [ax, deg] of spec || []) q.multiply(new THREE.Quaternion().setFromAxisAngle(new V(ax === 'X' ? 1 : 0, ax === 'Y' ? 1 : 0, ax === 'Z' ? 1 : 0), deg * D2R)); return q; };
  const reset = () => { for (const j of ALL) J[j].quaternion.identity(); J.Root.position.copy(J.Root.userData.c0); rig.root.updateMatrixWorld(true); };
  const setBody = body => { reset(); for (const [j, v] of Object.entries(body)) { if (v.r) J[j].quaternion.copy(rotQ(v.r)); if (v.p) J[j].position.copy(J[j].userData.c0).add(new V(...v.p)); } rig.root.updateMatrixWorld(true); };
  // blade = direction the blade points, edge = direction the cutting edge leads (made perpendicular)
  const sw = (blade, edge) => { const up = new V(...blade).normalize(), e = new V(...edge); e.addScaledVector(up, -e.dot(up)).normalize(); return { up, fwd: e, wUp: 7, wFwd: 3 }; };
  const body = (waistY = 0, lean = 0, rootY = 0, crouch = 0) => ({
    Root: { r: [['Y', rootY]], p: [0, -crouch, 0] }, Waist: { r: [['Y', waistY], ['X', -lean]] }, Neck: { r: [['Y', -waistY * 0.6 - rootY * 0.7]] },
    LeftHip: { r: [['X', 16], ['Z', -6]] }, LeftKnee: { r: [['X', -14 - crouch * 40]] }, LeftAnkle: { r: [['X', 2]] },
    RightHip: { r: [['X', -12], ['Z', 6]] }, RightKnee: { r: [['X', -10 - crouch * 30]] }, RightAnkle: { r: [['X', 6]] },
  });
  // right-hand goals; the left hand is solved onto the lower grip afterwards
  const guard = { rel: [-1.0, -1.0, -0.9], ...sw([0, 0.8, -0.6], [0, 0.6, 0.8]), elbowRel: [0, -0.75, -0.2] };
  const shoulder = bob => ({ rel: [-0.75, -0.7 + bob, -0.75], ...sw([0.35, 1, 0.85], [0, 1, -0.3]), elbowRel: [0.1, -0.8, -0.35] });
  const k = (t, b, R, marker) => ({ t, body: b, R, marker });
  const defs = {
    Hold: { loop: true, priority: 2, joints: ARMS, keys: [k(0, {}, shoulder(0)), k(1.2, {}, shoulder(0.04)), k(2.4, {}, shoulder(0))] },
    // A: heavy horizontal sweep, right → left
    Slash_A: { loop: false, priority: 3, joints: ALL, keys: [
      k(0, body(0, 0, 0, 0.05), shoulder(0)),
      k(0.2, body(-45, 0, -15, 0.12), { rel: [-0.2, -0.95, -0.15], ...sw([0.7, 0.35, 0.65], [-0.3, 0, -1]), elbowRel: [0.35, -0.65, 0.45] }, 'TrailOn'),
      k(0.33, body(10, 6, 5, 0.18), { rel: [-1.0, -0.85, -1.2], ...sw([-0.2, 0.1, -1], [-1, 0, 0.2]), elbowRel: [0, -0.6, -0.5] }, 'Hit'),
      k(0.46, body(30, 4, 10, 0.16), { rel: [-1.55, -0.9, 0.05], ...sw([-1, 0.05, 0.5], [0.4, 0, 1]), elbowRel: [-0.35, -0.75, -0.35] }, 'TrailOff'),
      k(0.75, body(5, 0, 0, 0.08), guard)] },
    // B: rising diagonal backswing, low-left → high-right
    Slash_B: { loop: false, priority: 3, joints: ALL, keys: [
      k(0, body(5, 0, 0, 0.08), guard),
      k(0.18, body(28, 4, 10, 0.16), { rel: [-1.5, -1.15, 0.05], ...sw([-0.8, -0.5, 0.35], [0.3, 0.4, -1]), elbowRel: [-0.35, -0.8, -0.35] }, 'TrailOn'),
      k(0.3, body(-5, 6, -2, 0.18), { rel: [-0.9, -0.6, -1.3], ...sw([0.35, 0.45, -1], [1, 0.5, 0.2]), elbowRel: [0, -0.55, -0.55] }, 'Hit'),
      k(0.42, body(-35, 0, -12, 0.1), { rel: [-0.35, 0.3, -0.85], ...sw([0.9, 0.7, 0.1], [0.2, 0.3, 1]), elbowRel: [0.3, -0.3, -0.25] }, 'TrailOff'),
      k(0.7, body(5, 0, 0, 0.08), guard)] },
    // C: overhead slam
    Slash_C: { loop: false, priority: 3, joints: ALL, keys: [
      k(0, body(5, 0, 0, 0.08), guard),
      k(0.3, body(-5, -8, -3, 0.02), { rel: [-1.0, 1.0, -0.05], ...sw([0, 0.3, 1], [0, 1, -0.3]), elbowRel: [0.1, 0.45, -0.4] }, 'TrailOn'),
      k(0.44, body(0, 18, 0, 0.3), { rel: [-1.0, -0.85, -1.35], ...sw([0, -0.45, -1], [0, -1, 0.45]), elbowRel: [0, -0.45, -0.75] }, 'Hit'),
      k(0.56, body(0, 20, 0, 0.32), { rel: [-1.0, -1.15, -1.1], ...sw([0, -0.75, -0.66], [0, -0.66, 0.75]), elbowRel: [0, -0.65, -0.6] }, 'TrailOff'),
      k(0.95, body(0, 0, 0, 0.06), shoulder(0))] },
  };
  // Walk: one-handed drag — blade trails behind, tip scraping the ground; heavy forward-leaning stride
  const wb = (sgn, pass) => pass ? {
      Root: { r: [['Y', 0]], p: [0, -0.02, 0] }, Waist: { r: [['X', -12], ['Y', 0]] }, Neck: { r: [['X', 8]] },
      LeftHip: { r: [['X', sgn > 0 ? 2 : 6]] }, LeftKnee: { r: [['X', sgn > 0 ? -8 : -50]] }, LeftAnkle: { r: [['X', sgn > 0 ? 4 : 18]] },
      RightHip: { r: [['X', sgn > 0 ? 6 : 2]] }, RightKnee: { r: [['X', sgn > 0 ? -50 : -8]] }, RightAnkle: { r: [['X', sgn > 0 ? 18 : 4]] },
      RightShoulder: { r: [['Z', 0]] } } : {
      Root: { r: [['Y', 5 * sgn]], p: [0, -0.16, 0] }, Waist: { r: [['X', -12], ['Y', 9 * sgn]] }, Neck: { r: [['X', 8], ['Y', -12 * sgn]] },
      LeftHip: { r: [['X', 30 * sgn]] }, LeftKnee: { r: [['X', sgn > 0 ? -8 : -24]] }, LeftAnkle: { r: [['X', sgn > 0 ? -14 : 14]] },
      RightHip: { r: [['X', -30 * sgn]] }, RightKnee: { r: [['X', sgn > 0 ? -24 : -8]] }, RightAnkle: { r: [['X', sgn > 0 ? 14 : -14]] } };
  const dragR = dz => ({ rel: [0.45, -1.5, 0.55 + dz], drag: true, elbowRel: [0.55, -0.8, 0.35] });
  defs.Walk = { loop: true, priority: 2, joints: ALL, keys: [
    { t: 0, body: wb(1), R: dragR(0.06), L: { relL: [-0.3, -1.7, 0.5] }, noLeftGrip: true },
    { t: 0.25, body: wb(1, true), R: dragR(0), L: { relL: [-0.32, -1.85, 0] }, noLeftGrip: true },
    { t: 0.5, body: wb(-1), R: dragR(-0.06), L: { relL: [-0.3, -1.6, -0.6] }, noLeftGrip: true },
    { t: 0.75, body: wb(-1, true), R: dragR(0), L: { relL: [-0.32, -1.85, 0] }, noLeftGrip: true },
    { t: 1.0, body: wb(1), R: dragR(0.06), L: { relL: [-0.3, -1.7, 0.5] }, noLeftGrip: true }] };
  const GM = gripMatrix(THREE), low = new V(0, GRIP_LOWER, 0);
  const out = {}; let lastL = null, lastR = null; const errs = [];
  for (const [name, def] of Object.entries(defs)) {
    const keys = [];
    for (const k of def.keys) {
      setBody(k.body);
      const RS = W(J.RightShoulder), LS = W(J.LeftShoulder);
      if (k.R.drag) { const hp = RS.clone().add(new V(...k.R.rel)), drop = hp.y - 0.1, side = 0.35, back = Math.sqrt(Math.max(0.01, DRAG_LEN ** 2 - drop ** 2 - side ** 2)); Object.assign(k.R, sw([side, -drop, back], [0, -1, 0.2])); }
      const gR = { hand: RS.clone().add(new V(...k.R.rel)), fwd: k.R.fwd, up: k.R.up, wUp: k.R.wUp, wFwd: k.R.wFwd, off: new V(...SWORD_GRIP.pos), elbow: k.R.elbowRel ? RS.clone().add(new V(...k.R.elbowRel)) : null };
      const sR = solveArm(THREE, rig, 'R', gR, lastR); lastR = sR.p;
      rig.root.updateMatrixWorld(true);
      const lowW = low.clone().applyMatrix4(new THREE.Matrix4().multiplyMatrices(rig.parts.RightHand.matrixWorld, GM));
      const gL = k.noLeftGrip ? { hand: LS.clone().add(new V(...k.L.relL)), off: new V(0, -0.1, 0) } : { hand: lowW, fwd: k.R.fwd, up: k.R.up, wUp: 1, wFwd: 0.4, off: new V(0, -0.1, 0) };
      let sL = null;
      for (const init of [lastL, null, [80, 40, -40, 60, 0, 0, 0], [60, -40, 20, 90, 0, 0, 0], [100, 0, -70, 30, 0, 0, 0]]) { const s = solveArm(THREE, rig, 'L', gL, init); if (!sL || s.err < sL.err) sL = s; }
      solveArm(THREE, rig, 'L', gL, sL.p); lastL = sL.p;
      { rig.root.updateMatrixWorld(true); const dR = rig.parts.RightHand.localToWorld(new V(...SWORD_GRIP.pos)).distanceTo(gR.hand), dL = rig.parts.LeftHand.localToWorld(new V(0, -0.1, 0)).distanceTo(gL.hand);
        const bl = new V(0, 1, 0).applyMatrix4(new THREE.Matrix4().extractRotation(new THREE.Matrix4().multiplyMatrices(rig.parts.RightHand.matrixWorld, GM))).normalize();
        errs.push([name, k.t, +dL.toFixed(3), +dR.toFixed(3), Math.round(Math.acos(Math.min(1, bl.dot(k.R.up))) * 57.3)]); }
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
export function swordLuau(c) {
  const server = `-- RubySwordEquip  (Script → StarterPlayer > StarterCharacterScripts)
-- Clones ReplicatedStorage.RubySword (two-handed greatsword), scales it for an R15 character, welds it to the RightHand
-- and adds a swing Trail (disabled; the client turns it on during swings).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SWORD_HEIGHT = ${f(c.swordHeight)}    -- studs, pommel to tip
local MODEL_HEIGHT = ${f(c.modelHeight)}    -- same, in model units (as exported)
local GRIP_CENTER = ${v3(c.gripCenter)}     -- Grip mesh centre in model units
local GRIP_POINT = Vector3.new(0, ${f(GRIP_UPPER)}, 0)  -- where the RightHand holds (upper grip), model units
local TRAIL_BASE = ${v3(c.trailBase)}       -- trail edge points in model units
local TRAIL_TIP = ${v3(c.trailTip)}

local character = script.Parent
local rightHand = character:WaitForChild("RightHand")

local sword = ReplicatedStorage:WaitForChild("RubySword"):Clone()
sword.Name = "RubySword"
sword:ScaleTo(sword:GetScale() * SWORD_HEIGHT / sword:GetExtentsSize().Y)
local S = SWORD_HEIGHT / MODEL_HEIGHT

local grip = sword:FindFirstChild("Grip", true)
assert(grip, "RubySword needs a part named Grip")
for _, p in sword:GetDescendants() do
	if p:IsA("BasePart") then
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		if p ~= grip then
			local wc = Instance.new("WeldConstraint")
			wc.Part0 = grip
			wc.Part1 = p
			wc.Parent = p
		end
	end
end

local function attach(name, modelPos)
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = (modelPos - GRIP_CENTER) * S
	a.Parent = grip
	return a
end
attach("SwordOrigin", Vector3.zero)
local a0, a1 = attach("TrailBase", TRAIL_BASE), attach("TrailTip", TRAIL_TIP)
local trail = Instance.new("Trail")
trail.Name = "SwingTrail"
trail.Attachment0, trail.Attachment1 = a0, a1
trail.Color = ColorSequence.new(Color3.fromRGB(255, 120, 100), Color3.fromRGB(216, 35, 47))
trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.4) })
trail.Lifetime = 0.16
trail.LightEmission = 0.8
trail.Enabled = false
trail.Parent = grip

-- sparks where the blade tip scrapes the ground while walking (client toggles Enabled)
local tip = attach("DragTip", TRAIL_TIP)
local sparks = Instance.new("ParticleEmitter")
sparks.Name = "DragSparks"
sparks.Color = ColorSequence.new(Color3.fromRGB(255, 220, 140), Color3.fromRGB(255, 90, 40))
sparks.LightEmission = 1
sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0) })
sparks.Lifetime = NumberRange.new(0.15, 0.35)
sparks.Rate = 45
sparks.Speed = NumberRange.new(4, 9)
sparks.SpreadAngle = Vector2.new(70, 70)
sparks.Acceleration = Vector3.new(0, -35, 0)
sparks.Drag = 2
sparks.Enabled = false
sparks.Parent = tip
sword:SetAttribute("StudsPerUnit", S)

local weld = Instance.new("Weld")
weld.Name = "SwordGrip"
weld.Part0 = rightHand
weld.Part1 = grip
-- blade up = hand -Z, cutting edge leads along hand -Y
weld.C0 = CFrame.new(${SWORD_GRIP.pos.join(', ')}) * CFrame.Angles(-math.pi / 2, 0, 0) * CFrame.Angles(0, math.pi / 2, 0)
weld.C1 = CFrame.new((GRIP_POINT - GRIP_CENTER) * S)
weld.Parent = grip
sword.Parent = character
-- The LeftHand is not welded: the animations place it on the lower grip (two-handed).
`;
  const client = `-- RubySwordAnimator  (LocalScript → StarterPlayer > StarterCharacterScripts)
-- Plays the sword idle + 3-hit combo, toggles the swing trail and runs a hit box at each "Hit" marker.
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Paste published animation ids here (rbxassetid://...). Leave "" to use the
-- KeyframeSequences in ReplicatedStorage.RubySwordAnimations (Studio play-testing only).
local ANIM_IDS = { Hold = "", Walk = "", Slash_A = "", Slash_B = "", Slash_C = "" }

local AUTO_ATTACK = true          -- Archero style: keep swinging while standing still
local COMBO = { "Slash_A", "Slash_B", "Slash_C" }
local COMBO_RESET = 0.6           -- seconds after a swing ends before the combo restarts at A
local SPEED = 1.0                 -- animation speed multiplier (attack speed upgrades)
local WALK_ANIM_SPEED = 6         -- studs/s at which Sword_Walk plays at 1x (the stride is matched to this)
local HITBOX = Vector3.new(9, 6, 8)   -- studs, in front of the character (greatsword reach)
local function hasTarget()        -- replace with your own "is an enemy alive?" check
	return true
end
local function onHit(humanoids: { Humanoid }, swing: string)
	-- Fire a RemoteEvent here; the server should re-check range and apply damage.
end

local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")
local animator = humanoid:WaitForChild("Animator")
local root = character:WaitForChild("HumanoidRootPart")
local sword = character:WaitForChild("RubySword")
local grip = sword:FindFirstChild("Grip", true)
local trail = grip:WaitForChild("SwingTrail")

local folder = ReplicatedStorage:FindFirstChild("RubySwordAnimations")
local function loadTrack(name)
	local id = ANIM_IDS[name]
	if id == "" then
		local kfs = folder and folder:FindFirstChild("Sword_" .. name)
		assert(kfs, "No animation id or KeyframeSequence for " .. name)
		id = game:GetService("KeyframeSequenceProvider"):RegisterKeyframeSequence(kfs)
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	return animator:LoadAnimation(anim)
end
local tracks = {}
for _, name in { "Hold", "Walk", "Slash_A", "Slash_B", "Slash_C" } do
	tracks[name] = loadTrack(name)
end
tracks.Hold.Priority = Enum.AnimationPriority.Action
tracks.Hold.Looped = true
tracks.Hold:Play(0.2)
-- full-body drag walk; Action priority so it overrides the default Animate walk/run
tracks.Walk.Priority = Enum.AnimationPriority.Action
tracks.Walk.Looped = true
local sparks = grip:FindFirstChild("DragSparks", true)

local params = OverlapParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { character }

local function hitbox(swing)
	local cf = root.CFrame * CFrame.new(0, 0, -HITBOX.Z / 2)
	local found, list = {}, {}
	for _, part in workspace:GetPartBoundsInBox(cf, HITBOX, params) do
		local h = part.Parent and part.Parent:FindFirstChildOfClass("Humanoid")
		if h and h.Health > 0 and not found[h] then
			found[h] = true
			table.insert(list, h)
		end
	end
	if #list > 0 then onHit(list, swing) end
end

local swinging, comboIndex, lastEnd = false, 1, 0
for _, name in COMBO do
	local tr = tracks[name]
	tr.Priority = Enum.AnimationPriority.Action2
	tr.Looped = false
	tr:GetMarkerReachedSignal("TrailOn"):Connect(function() trail.Enabled = true end)
	tr:GetMarkerReachedSignal("TrailOff"):Connect(function() trail.Enabled = false end)
	tr:GetMarkerReachedSignal("Hit"):Connect(function() hitbox(name) end)
	tr.Stopped:Connect(function()
		trail.Enabled = false
		swinging = false
		lastEnd = os.clock()
	end)
end

local function attack()
	if swinging then return end
	if os.clock() - lastEnd > COMBO_RESET then comboIndex = 1 end
	local name = COMBO[comboIndex]
	comboIndex = comboIndex % #COMBO + 1
	swinging = true
	if tracks.Walk.IsPlaying then
		tracks.Walk:Stop(0.1)
		tracks.Hold:Play(0.1)
	end
	tracks[name]:Play(0.05, 1, SPEED)
end

-- swap Hold ↔ Walk with movement, sync stride to ground speed, sparks while dragging
RunService.Heartbeat:Connect(function()
	local planar = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
	local moving = humanoid.MoveDirection.Magnitude > 0.05 and planar > 0.5 and humanoid.FloorMaterial ~= Enum.Material.Air
	if moving and not swinging then
		if not tracks.Walk.IsPlaying then
			tracks.Hold:Stop(0.25)
			tracks.Walk:Play(0.25)
		end
		tracks.Walk:AdjustSpeed(math.clamp(planar / WALK_ANIM_SPEED, 0.6, 2.2))
	elseif tracks.Walk.IsPlaying then
		tracks.Walk:Stop(0.25)
		tracks.Hold:Play(0.25)
	end
	if sparks then sparks.Enabled = tracks.Walk.IsPlaying end
end)

if AUTO_ATTACK then
	RunService.Heartbeat:Connect(function()
		if humanoid.MoveDirection.Magnitude < 0.05 and hasTarget() then attack() end
	end)
else
	ContextActionService:BindAction("RubySwordAttack", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then attack() end
		return Enum.ContextActionResult.Pass
	end, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
end
`;
  return { server, client };
}
