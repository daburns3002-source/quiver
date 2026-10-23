// R15 rig (blocky proportions), Leaf Bow animation data, IK bake, and Roblox kit (.rbxmx) export.
export const SIZES = {
  LowerTorso: [2, 0.4, 1], UpperTorso: [2, 1.6, 1], Head: [1.2, 1.2, 1.2],
  LeftUpperArm: [1, 1.169, 1], LeftLowerArm: [1, 1.052, 1], LeftHand: [1, 0.3, 1],
  RightUpperArm: [1, 1.169, 1], RightLowerArm: [1, 1.052, 1], RightHand: [1, 0.3, 1],
  LeftUpperLeg: [1, 1.2, 1], LeftLowerLeg: [1, 1.2, 1], LeftFoot: [1, 0.3, 1],
  RightUpperLeg: [1, 1.2, 1], RightLowerLeg: [1, 1.2, 1], RightFoot: [1, 0.3, 1],
};
// [joint, part0, part1, C0, C1]
export const JOINTS = [
  ['Root', 'HumanoidRootPart', 'LowerTorso', [0, -0.25, 0], [0, 0, 0]],
  ['Waist', 'LowerTorso', 'UpperTorso', [0, 0.2, 0], [0, -0.8, 0]],
  ['Neck', 'UpperTorso', 'Head', [0, 0.8, 0], [0, -0.5, 0]],
  ['LeftShoulder', 'UpperTorso', 'LeftUpperArm', [-1, 0.563, 0], [0.5, 0.392, 0]],
  ['LeftElbow', 'LeftUpperArm', 'LeftLowerArm', [0, -0.334, 0], [0, 0.26, 0]],
  ['LeftWrist', 'LeftLowerArm', 'LeftHand', [0, -0.5, 0], [0, 0.125, 0]],
  ['RightShoulder', 'UpperTorso', 'RightUpperArm', [1, 0.563, 0], [-0.5, 0.392, 0]],
  ['RightElbow', 'RightUpperArm', 'RightLowerArm', [0, -0.334, 0], [0, 0.26, 0]],
  ['RightWrist', 'RightLowerArm', 'RightHand', [0, -0.5, 0], [0, 0.125, 0]],
  ['LeftHip', 'LowerTorso', 'LeftUpperLeg', [-0.5, -0.2, 0], [0, 0.42, 0]],
  ['LeftKnee', 'LeftUpperLeg', 'LeftLowerLeg', [0, -0.45, 0], [0, 0.3, 0]],
  ['LeftAnkle', 'LeftLowerLeg', 'LeftFoot', [0, -0.45, 0], [0, 0.1, 0]],
  ['RightHip', 'LowerTorso', 'RightUpperLeg', [0.5, -0.2, 0], [0, 0.42, 0]],
  ['RightKnee', 'RightUpperLeg', 'RightLowerLeg', [0, -0.45, 0], [0, 0.3, 0]],
  ['RightAnkle', 'RightLowerLeg', 'RightFoot', [0, -0.45, 0], [0, 0.1, 0]],
];
export const HRP_Y = 2.35;
export const BOW_SCALE = 3.8;                 // studs per bow-model unit
export const GRIP_C0 = { pos: [0, -0.15, 0], rotX: -Math.PI / 2 };   // LeftHand -> bow origin
const ARM_L = ['LeftShoulder', 'LeftElbow', 'LeftWrist'], ARM_R = ['RightShoulder', 'RightElbow', 'RightWrist'];
const ALL = JOINTS.map(j => j[0]);

export function buildRig(THREE, colors = {}) {
  const root = new THREE.Group(); root.name = 'R15';
  const parts = {}, joints = {};
  const hrp = new THREE.Object3D(); hrp.name = 'HumanoidRootPart'; hrp.position.set(0, HRP_Y, 0); root.add(hrp); parts.HumanoidRootPart = hrp;
  for (const [name, s] of Object.entries(SIZES)) {
    const o = new THREE.Object3D(); o.name = name; parts[name] = o;
    const col = colors[name] || (/Torso/.test(name) ? '#5C6F8F' : /Leg|Foot/.test(name) ? '#4A5568' : '#E9D2B6');
    const m = new THREE.Mesh(new THREE.BoxGeometry(s[0] * 0.98, s[1] * 0.98, s[2] * 0.98), new THREE.MeshStandardMaterial({ color: col, roughness: 0.7 }));
    m.castShadow = true; m.receiveShadow = true; o.add(m);
  }
  for (const [j, p0, p1, c0, c1] of JOINTS) {
    const jn = new THREE.Object3D(); jn.name = j; jn.position.set(...c0); jn.userData.c0 = new THREE.Vector3(...c0);
    parts[p0].add(jn); jn.add(parts[p1]); parts[p1].position.set(-c1[0], -c1[1], -c1[2]); joints[j] = jn;
  }
  // face hint so facing direction reads (-Z)
  const eye = new THREE.MeshStandardMaterial({ color: '#2a2a2a', roughness: 0.6 });
  for (const x of [-0.22, 0.22]) { const e = new THREE.Mesh(new THREE.BoxGeometry(0.14, 0.22, 0.04), eye); e.position.set(x, 0.08, -0.61); parts.Head.add(e); }
  return { root, parts, joints };
}

// ---------- pose helpers ----------
const D2R = Math.PI / 180;
function rotQ(THREE, spec) { const q = new THREE.Quaternion(); for (const [ax, deg] of spec || []) q.multiply(new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(ax === 'X' ? 1 : 0, ax === 'Y' ? 1 : 0, ax === 'Z' ? 1 : 0), deg * D2R)); return q; }

function solveArm(THREE, rig, side, goal, init) {
  const V = THREE.Vector3, [sh, el, wr] = side === 'L' ? ARM_L : ARM_R, hand = rig.parts[side === 'L' ? 'LeftHand' : 'RightHand'], ut = rig.parts.UpperTorso;
  const useWrist = !!goal.fwd, n = useWrist ? 7 : 4, p = init ? init.slice(0, n) : (side === 'L' ? [60, 0, -10, 20, 0, 0, 0] : [40, 0, 10, 30]).slice(0, n);
  const off = side === 'L' ? new V(...GRIP_C0.pos) : new V(0, -0.1, 0);
  const tmp = new V(), ax = new V(), e = new THREE.Euler();
  const apply = q => {
    rig.joints[sh].quaternion.setFromEuler(e.set(q[0] * D2R, q[1] * D2R, q[2] * D2R, 'XYZ'));
    rig.joints[el].quaternion.setFromEuler(e.set(q[3] * D2R, 0, 0, 'XYZ'));
    rig.joints[wr].quaternion.setFromEuler(useWrist ? e.set(q[4] * D2R, q[5] * D2R, q[6] * D2R, 'XYZ') : e.set(0, 0, 0));
    ut.updateMatrixWorld(true);
  };
  const cost = q => {
    apply(q); let c = hand.localToWorld(tmp.copy(off)).distanceToSquared(goal.hand) * 30;
    if (useWrist) { const m = hand.matrixWorld; ax.setFromMatrixColumn(m, 1).normalize().negate(); c += (1 - ax.dot(goal.fwd)) * 6; ax.setFromMatrixColumn(m, 2).normalize().negate(); c += (1 - ax.dot(goal.up)) * 3; c += 4e-5 * (q[4] ** 2 + q[5] ** 2 + q[6] ** 2); }
    if (goal.elbow) c += rig.joints[el].getWorldPosition(tmp).distanceToSquared(goal.elbow) * 0.35;
    if (q[3] < 0) c += q[3] ** 2 * 0.01; if (q[3] > 150) c += (q[3] - 150) ** 2 * 0.01;
    return c;
  };
  let best = cost(p);
  for (const st of [24, 12, 6, 3, 1.5, 0.75, 0.3, 0.12]) {
    for (let it = 0; it < 40; it++) { let imp = false;
      for (let i = 0; i < n; i++) for (const s of [st, -st]) { p[i] += s; const c = cost(p); if (c < best - 1e-9) { best = c; imp = true; } else p[i] -= s; }
      if (!imp) break; }
  }
  apply(p); return { p, err: Math.sqrt(best / 30) };
}

// Build keyframes for every animation, solving arm IK on the preview rig.
export function bakeAnimations(THREE, rig, bowRig) {
  const V = THREE.Vector3, J = rig.joints, P = rig.parts;
  const W = o => o.getWorldPosition(new V());
  const reset = () => { for (const j of ALL) J[j].quaternion.identity(); J.Root.position.copy(J.Root.userData.c0); rig.root.updateMatrixWorld(true); };
  const setBody = body => { reset(); for (const [j, v] of Object.entries(body)) { if (v.r) J[j].quaternion.copy(rotQ(THREE, v.r)); if (v.p) J[j].position.copy(J[j].userData.c0).add(new V(...v.p)); } rig.root.updateMatrixWorld(true); };
  const D = new V(0, 0, -1), UP = new V(0, 1, 0);
  const aimBody = (k = 1, extraWaist = 0) => ({
    Root: { r: [['Y', -35 * k]], p: [0, -0.12 * k, 0] }, Waist: { r: [['Y', (-30 + extraWaist) * k]] }, Neck: { r: [['Y', 55 * k], ['X', -4 * k]] },
    LeftHip: { r: [['X', 14 * k], ['Z', -7 * k]] }, LeftKnee: { r: [['X', -16 * k]] }, LeftAnkle: { r: [['X', 4 * k]] },
    RightHip: { r: [['X', -10 * k], ['Z', 7 * k]] }, RightKnee: { r: [['X', -14 * k]] }, RightAnkle: { r: [['X', 8 * k]] },
  });
  // reference points at full draw
  setBody(aimBody());
  const head = W(P.Head), LS = W(J.LeftShoulder), RS0 = W(J.RightShoulder), chin = head.clone().add(new V(0.28, -0.62, -0.46));
  const H = RS0.clone().add(chin.clone().sub(RS0).clampLength(0, 1.45));
  let lo = 0.5, hi = 4; for (let i = 0; i < 40; i++) { const s = (lo + hi) / 2; if (H.clone().addScaledVector(D, s).distanceTo(LS) < 1.72) lo = s; else hi = s; }
  const drawLen = lo, LH = H.clone().addScaledVector(D, drawLen), Hrest = LH.clone().addScaledVector(D, -bowRig.zRest * BOW_SCALE);
  const elbowR = h => h.clone().add(new V(0.25, 0.05, 1.0));
  const zr = bowRig.zRest * BOW_SCALE;
  let a1 = zr, b1 = drawLen; for (let i = 0; i < 40; i++) { const s = (a1 + b1) / 2; if (H.clone().addScaledVector(D, s - zr).distanceTo(RS0) < 1.62) a1 = s; else b1 = s; }
  const LH1 = H.clone().addScaledVector(D, a1), Hrest1 = LH1.clone().addScaledVector(D, -zr), LH2 = LH1.clone().lerp(LH, 0.65), H2 = Hrest1.clone().lerp(H, 0.65);
  const aimL = (dLH = new V(), fwd = D) => ({ hand: LH.clone().add(dLH), fwd, up: UP });

  const defs = {
    Hold: { loop: true, priority: 2, joints: [...ARM_L, ...ARM_R], keys: [
      { t: 0, body: {}, L: 'hold', R: 'hold' }, { t: 1.2, body: {}, L: 'hold', R: 'hold', bob: 0.03 }, { t: 2.4, body: {}, L: 'hold', R: 'hold' }] },
    Draw: { loop: false, priority: 3, joints: ALL, keys: [
      { t: 0, body: aimBody(0.45), L: { hand: LH1.clone().add(new V(0.3, -0.7, 0.2)), fwd: new V(0, -0.35, -1).normalize(), up: UP }, R: { hand: Hrest1.clone().add(new V(0.3, -0.6, 0.3)), elbow: null } },
      { t: 0.16, body: aimBody(), L: { hand: LH1, fwd: D, up: UP }, R: { hand: Hrest1, elbow: elbowR(Hrest1) }, marker: 'Nock' },
      { t: 0.3, body: aimBody(), L: { hand: LH2, fwd: D, up: UP }, R: { hand: H2, elbow: elbowR(H2) } },
      { t: 0.45, body: aimBody(), L: aimL(), R: { hand: H, elbow: elbowR(H) } }] },
    Aim: { loop: true, priority: 3, joints: ALL, keys: [
      { t: 0, body: aimBody(), L: aimL(), R: { hand: H, elbow: elbowR(H) } },
      { t: 0.6, body: { ...aimBody(), Waist: { r: [['Y', -30], ['X', 1.5]] } }, L: aimL(new V(0, 0.015, 0)), R: { hand: H.clone().add(new V(0, 0.02, 0.04)), elbow: elbowR(H) } },
      { t: 1.2, body: aimBody(), L: aimL(), R: { hand: H, elbow: elbowR(H) } }] },
    Fire: { loop: false, priority: 3, joints: ALL, keys: [
      { t: 0, body: aimBody(), L: aimL(), R: { hand: H, elbow: elbowR(H) } },
      { t: 0.03, body: aimBody(), L: aimL(), R: { hand: H, elbow: elbowR(H) }, marker: 'Release' },
      { t: 0.13, body: aimBody(1, -4), L: aimL(new V(0, -0.04, -0.12)), R: { hand: H.clone().add(new V(0.38, 0.12, 0.5)), elbow: elbowR(H).add(new V(0.2, 0, 0.2)) } },
      { t: 0.42, body: aimBody(0.85), L: aimL(new V(0.05, -0.3, 0.2), new V(0, -0.2, -1).normalize()), R: { hand: null, rel: [0.55, -1.25, 0.15], elbow: null } }] },
  };

  const out = {}; let lastL = null, lastR = null; const errs = [];
  for (const [name, def] of Object.entries(defs)) {
    const keys = [];
    for (const k of def.keys) {
      setBody(k.body);
      const RS = W(J.RightShoulder), LSk = W(J.LeftShoulder);
      let gL = k.L, gR = k.R;
      if (gL === 'hold') gL = { hand: LSk.clone().add(new V(-0.3, -1.45 + (k.bob || 0), -0.5)), fwd: new V(0, -0.38, -0.92).normalize(), up: new V(0.05, 0.92, -0.38).normalize() };
      if (gR === 'hold') gR = { hand: RS.clone().add(new V(0.3, -1.55 + (k.bob || 0), -0.2)), elbow: RS.clone().add(new V(0.45, -0.8, 0.2)) };
      if (gR.rel) gR = { hand: RS.clone().add(new V(...gR.rel)), elbow: RS.clone().add(new V(0.5, -0.7, 0.3)) };
      const sL = solveArm(THREE, rig, 'L', gL, lastL), sR = solveArm(THREE, rig, 'R', gR, lastR); lastL = sL.p; lastR = sR.p;
      errs.push([name, k.t, +sL.err.toFixed(3), +sR.err.toFixed(3)]);
      const rot = {}, pos = {};
      for (const j of def.joints) rot[j] = J[j].quaternion.clone();
      if (def.joints.includes('Root')) pos.Root = J.Root.position.clone().sub(J.Root.userData.c0);
      keys.push({ t: k.t, rot, pos, marker: k.marker });
    }
    out[name] = { name, loop: def.loop, priority: def.priority, joints: def.joints, keys, length: def.keys[def.keys.length - 1].t };
  }
  reset();
  return { anims: out, drawLen, errs };
}

// sample an animation at time t -> {rot, pos}
const ease = t => t < 0.5 ? 4 * t * t * t : 1 - (-2 * t + 2) ** 3 / 2;
export function sampleAnim(THREE, A, t) {
  const k = A.keys; if (A.loop) t = ((t % A.length) + A.length) % A.length; else t = Math.min(t, A.length);
  let i = 0; while (i < k.length - 2 && t > k[i + 1].t) i++;
  const a = k[i], b = k[Math.min(i + 1, k.length - 1)], u = b.t > a.t ? ease(Math.min(1, Math.max(0, (t - a.t) / (b.t - a.t)))) : 0;
  const rot = {}, pos = {};
  for (const j of A.joints) rot[j] = a.rot[j].clone().slerp(b.rot[j], u);
  if (a.pos.Root) pos.Root = a.pos.Root.clone().lerp(b.pos.Root, u);
  return { rot, pos };
}

// ---------- Roblox XML ----------
const TREE = { HumanoidRootPart: ['LowerTorso'], LowerTorso: ['UpperTorso', 'LeftUpperLeg', 'RightUpperLeg'], UpperTorso: ['Head', 'LeftUpperArm', 'RightUpperArm'], LeftUpperArm: ['LeftLowerArm'], LeftLowerArm: ['LeftHand'], RightUpperArm: ['RightLowerArm'], RightLowerArm: ['RightHand'], LeftUpperLeg: ['LeftLowerLeg'], LeftLowerLeg: ['LeftFoot'], RightUpperLeg: ['RightLowerLeg'], RightLowerLeg: ['RightFoot'] };
const PART_JOINT = Object.fromEntries(JOINTS.map(j => [j[2], j[0]]));
const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const f = x => (Math.abs(x) < 1e-7 ? 0 : x).toFixed(6);

export function kitXML(THREE, anims, scripts) {
  let ref = 0; const R = () => 'RBX' + (ref++).toString(16).toUpperCase().padStart(6, '0');
  const cf = (q, p) => { const m = new THREE.Matrix4().makeRotationFromQuaternion(q || new THREE.Quaternion()), e = m.elements, P = p || { x: 0, y: 0, z: 0 };
    return `<CoordinateFrame name="CFrame"><X>${f(P.x)}</X><Y>${f(P.y)}</Y><Z>${f(P.z)}</Z><R00>${f(e[0])}</R00><R01>${f(e[4])}</R01><R02>${f(e[8])}</R02><R10>${f(e[1])}</R10><R11>${f(e[5])}</R11><R12>${f(e[9])}</R12><R20>${f(e[2])}</R20><R21>${f(e[6])}</R21><R22>${f(e[10])}</R22></CoordinateFrame>`; };
  const needs = (part, A) => { const j = PART_JOINT[part]; if (j && A.joints.includes(j)) return true; return (TREE[part] || []).some(c => needs(c, A)); };
  const pose = (part, A, key) => {
    if (!needs(part, A)) return '';
    const j = PART_JOINT[part], live = j && A.joints.includes(j);
    const kids = (TREE[part] || []).map(c => pose(c, A, key)).join('');
    return `<Item class="Pose" referent="${R()}"><Properties>${cf(live ? key.rot[j] : null, live && j === 'Root' ? key.pos.Root : null)}<token name="EasingDirection">2</token><token name="EasingStyle">3</token><string name="Name">${part}</string><float name="Weight">${live ? 1 : 0}</float></Properties>${kids}</Item>`;
  };
  const kfs = A => `<Item class="KeyframeSequence" referent="${R()}"><Properties><string name="Name">Bow_${A.name}</string><bool name="Loop">${A.loop}</bool><token name="Priority">${A.priority}</token></Properties>` +
    A.keys.map(k => `<Item class="Keyframe" referent="${R()}"><Properties><string name="Name">${k.marker || 'Keyframe'}</string><float name="Time">${f(k.t)}</float></Properties>${pose('HumanoidRootPart', A, k)}${k.marker ? `<Item class="KeyframeMarker" referent="${R()}"><Properties><string name="Name">${k.marker}</string><string name="Value"></string></Properties></Item>` : ''}</Item>`).join('') + `</Item>`;
  const scr = (cls, name, src) => `<Item class="${cls}" referent="${R()}"><Properties><string name="Name">${name}</string><bool name="Disabled">false</bool><ProtectedString name="Source"><![CDATA[${src}]]></ProtectedString></Properties></Item>`;
  return `<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">` +
    `<Item class="Folder" referent="${R()}"><Properties><string name="Name">LeafBowKit</string></Properties>` +
    `<Item class="Folder" referent="${R()}"><Properties><string name="Name">LeafBowAnimations</string></Properties>${Object.values(anims).map(kfs).join('')}</Item>` +
    scr('Script', 'LeafBowEquip', scripts.server) + scr('LocalScript', 'LeafBowAnimator', scripts.client) + `</Item></roblox>`;
}

// ---------- Luau ----------
const v3 = v => `Vector3.new(${f(v.x)}, ${f(v.y)}, ${f(v.z)})`;
export function luau(c) {
  const server = `-- LeafBowEquip  (Script → StarterPlayer > StarterCharacterScripts)
-- Clones ReplicatedStorage.LeafBow, scales it for an R15 character and welds it to the LeftHand.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BOW_HEIGHT = ${f(c.bowHeight)}       -- studs, tip to tip
local MODEL_HEIGHT = ${f(c.modelHeight)}   -- bow height in model units (as exported)
local GRIP_CENTER = ${v3(c.gripCenter)}    -- Grip mesh centre in model units

local character = script.Parent
local leftHand = character:WaitForChild("LeftHand")

local bow = ReplicatedStorage:WaitForChild("LeafBow"):Clone()
bow.Name = "LeafBow"
bow:ScaleTo(bow:GetScale() * BOW_HEIGHT / bow:GetExtentsSize().Y)
local S = BOW_HEIGHT / MODEL_HEIGHT

local grip = bow:FindFirstChild("Grip", true)
assert(grip, "LeafBow needs a part named Grip")
for _, p in bow:GetDescendants() do
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

local origin = Instance.new("Attachment")
origin.Name = "BowOrigin"            -- bow model origin: grip centre, -Z = shooting direction
origin.CFrame = CFrame.new(-GRIP_CENTER * S)
origin.Parent = grip
bow:SetAttribute("StudsPerUnit", S)

local weld = Instance.new("Weld")
weld.Name = "BowGrip"
weld.Part0 = leftHand
weld.Part1 = grip
weld.C0 = CFrame.new(${GRIP_C0.pos.join(', ')}) * CFrame.Angles(-math.pi / 2, 0, 0)
weld.C1 = CFrame.new(-GRIP_CENTER * S)
weld.Parent = grip
bow.Parent = character
`;
  const client = `-- LeafBowAnimator  (LocalScript → StarterPlayer > StarterCharacterScripts)
-- Plays the bow animations, pulls the string with the right hand and fires arrows.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

-- Paste published animation ids here (rbxassetid://...). Leave "" to use the
-- KeyframeSequences in ReplicatedStorage.LeafBowAnimations (Studio play-testing only).
local ANIM_IDS = { Hold = "", Draw = "", Aim = "", Fire = "" }

local AUTO_FIRE = true     -- Archero style: keep shooting while standing still
local AIM_TIME = 0.12      -- seconds at full draw before an auto release
local ARROW_SPEED = 90     -- studs per second
local ARROW_RANGE = 80     -- studs
local function hasTarget() -- replace with your own "is an enemy alive?" check
	return true
end
local function onShot(origin: Vector3, direction: Vector3)
	-- Fire a RemoteEvent here so the server can raycast and apply damage.
end

-- Bow reference points in model units (origin = grip centre, -Z = forward)
local ANCHOR_TOP = ${v3(c.anchorTop)}
local ANCHOR_BOTTOM = ${v3(c.anchorBottom)}
local REST_NOCK = ${v3(c.restNock)}
local ARROW_REST = ${v3(c.arrowRest)}
local ARROW_LENGTH = ${f(c.arrowLength)}
local STRING_DIAMETER = 0.0056

local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")
local animator = humanoid:WaitForChild("Animator")
local rightHand = character:WaitForChild("RightHand")
local bow = character:WaitForChild("LeafBow")
local grip = bow:FindFirstChild("Grip", true)
local origin = grip:WaitForChild("BowOrigin")
local S = bow:GetAttribute("StudsPerUnit")
while not S do
	bow:GetAttributeChangedSignal("StudsPerUnit"):Wait()
	S = bow:GetAttribute("StudsPerUnit")
end

-- animations
local folder = ReplicatedStorage:FindFirstChild("LeafBowAnimations")
local function loadTrack(name)
	local id = ANIM_IDS[name]
	if id == "" then
		local kfs = folder and folder:FindFirstChild("Bow_" .. name)
		assert(kfs, "No animation id or KeyframeSequence for " .. name)
		id = game:GetService("KeyframeSequenceProvider"):RegisterKeyframeSequence(kfs)
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	return animator:LoadAnimation(anim)
end
local tracks = {}
for _, name in { "Hold", "Draw", "Aim", "Fire" } do
	tracks[name] = loadTrack(name)
end
tracks.Hold.Priority = Enum.AnimationPriority.Action
tracks.Hold.Looped = true
tracks.Aim.Looped = true
for _, name in { "Draw", "Aim", "Fire" } do
	tracks[name].Priority = Enum.AnimationPriority.Action2
end
tracks.Hold:Play(0.2)

-- live string (local visual; the exported string meshes are hidden)
for _, n in { "String_Upper", "String_Lower" } do
	local p = bow:FindFirstChild(n, true)
	if p then p.Transparency = 1 end
end
local function newString()
	local p = Instance.new("Part")
	p.Name = "BowString"
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = Color3.fromRGB(236, 226, 199)
	p.Parent = workspace.CurrentCamera
	return p
end
local upper, lower = newString(), newString()
local THICK = math.max(0.03, STRING_DIAMETER * S)

-- arrow
local arrow = ReplicatedStorage:WaitForChild("LeafArrow"):Clone()
for _, p in arrow:GetDescendants() do
	if p:IsA("BasePart") then
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
	end
end
arrow:ScaleTo(arrow:GetScale() * (ARROW_LENGTH * S) / arrow:GetExtentsSize().Z)
arrow.WorldPivot = (arrow:GetBoundingBox())
local HALF = arrow:GetExtentsSize().Z / 2

local state, engaged, releasedAt = "idle", false, -1

local function launch()
	local a = arrow:Clone()
	a.Parent = workspace
	local cf = a:GetPivot()
	local dir = cf.LookVector
	onShot(cf.Position, dir)
	local travelled, conn = 0, nil
	conn = RunService.Heartbeat:Connect(function(dt)
		local step = ARROW_SPEED * dt
		travelled += step
		a:PivotTo(a:GetPivot() + dir * step)
		if travelled >= ARROW_RANGE then
			conn:Disconnect()
			a:Destroy()
		end
	end)
end

tracks.Draw:GetMarkerReachedSignal("Nock"):Connect(function()
	if state == "drawing" then
		engaged = true
		arrow.Parent = workspace.CurrentCamera
	end
end)
tracks.Draw.Stopped:Connect(function()
	if state == "drawing" then
		state = "aiming"
		tracks.Aim:Play(0.05)
	end
end)
tracks.Fire:GetMarkerReachedSignal("Release"):Connect(function()
	engaged = false
	releasedAt = os.clock()
	if arrow.Parent then
		launch()
		arrow.Parent = nil
	end
end)
tracks.Fire.Stopped:Connect(function()
	if state == "firing" then state = "idle" end
end)

local function startDraw()
	if state ~= "idle" then return end
	state, engaged = "drawing", false
	tracks.Fire:Stop(0.1)
	tracks.Draw:Play(0.12)
end
local function release()
	if state == "drawing" and not engaged then
		state = "idle"
		tracks.Draw:Stop(0.15)
		return
	end
	if state ~= "drawing" and state ~= "aiming" then return end
	state = "firing"
	tracks.Draw:Stop(0.05)
	tracks.Aim:Stop(0.05)
	tracks.Fire:Play(0.03)
end
local function cancel()
	if state == "drawing" or state == "aiming" then
		state, engaged = "idle", false
		arrow.Parent = nil
		tracks.Draw:Stop(0.15)
		tracks.Aim:Stop(0.15)
	end
end

if AUTO_FIRE then
	local aimStart = nil
	RunService.Heartbeat:Connect(function()
		if humanoid.MoveDirection.Magnitude > 0.05 or not hasTarget() then
			cancel()
			aimStart = nil
		elseif state == "idle" then
			startDraw()
		elseif state == "aiming" then
			aimStart = aimStart or os.clock()
			if os.clock() - aimStart >= AIM_TIME then
				aimStart = nil
				release()
			end
		end
	end)
else
	ContextActionService:BindAction("LeafBowShoot", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			startDraw()
		elseif inputState == Enum.UserInputState.End then
			release()
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
end

local function segment(part, a, b)
	part.Size = Vector3.new((b - a).Magnitude, THICK, THICK)
	part.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0)
end
local render = RunService.RenderStepped:Connect(function()
	local o = origin.WorldCFrame
	local top, bottom = o * (ANCHOR_TOP * S), o * (ANCHOR_BOTTOM * S)
	local nock
	if engaged then
		nock = rightHand.CFrame * Vector3.new(0, -0.1, 0)
	else
		local t = os.clock() - releasedAt
		local wobble = (releasedAt > 0 and t < 0.6) and 0.07 * S * math.exp(-t * 9) * math.sin(t * 55) or 0
		nock = o * (REST_NOCK * S) + o.LookVector * wobble
	end
	segment(upper, top, nock)
	segment(lower, bottom, nock)
	if engaged and arrow.Parent then
		local rest = o * (ARROW_REST * S)
		arrow:PivotTo(CFrame.lookAt(nock, rest) * CFrame.new(0, 0, -HALF))
	end
end)

humanoid.Died:Connect(function()
	render:Disconnect()
	upper:Destroy()
	lower:Destroy()
	arrow:Destroy()
end)
`;
  return { server, client };
}
