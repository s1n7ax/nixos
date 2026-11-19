// The office drawn in 3D and seen from straight above, for the Frequent card's plan. The card
// lays its spots, labels and air on top in the same coordinates: plan units, 1 unit = 5 cm, the
// room 3 wide by 4 tall, roughly to scale (67.1 × 89.5). The furniture models are ported from NeonPlan 3D's built-in, procedural
// low-poly furniture (Mastershort, MIT, vendor/neonplan3d.LICENSE): boxes, lofts and cylinders
// in local metres (x across, z depth with the front at +z, y up), turned and moved into place.

import * as THREE from "./vendor/three.module.min.js";

export const UNIT = 0.05;
export const PLAN = [67.1, 89.5];
const ROOM = PLAN.map((v) => v * UNIT);
const WALL = 0.1;

// NeonPlan's neon palette.
const C = {
  body: 0x172238, bodyTop: 0x1d2b47, fabric: 0x1a2644, fabricTop: 0x22325a, cushion: 0x243661,
  wood: 0x19233c, woodTop: 0x202d4b, white: 0x1d2946, whiteTop: 0x26375e, metal: 0x2a3a60, dark: 0x0b111f,
};
const EDGE = 0x2a3b80;
const EDGE_FAINT = 0x182350;
const AC_Y = 2.05;
const CEILING_Y = 2.6;
// A ceiling light's face while it is off.
const FITTING = 0x3a424e;
// An active spot's furniture: tinted toward the air's colour and lit from within.
const COOL = 0x7cc7ff;

const materials = new Map();
const material = (color, glow = 0) => {
  const key = `${color}|${glow}`;
  if (!materials.has(key)) {
    materials.set(key, new THREE.MeshStandardMaterial({ color, roughness: 0.85, metalness: 0.05, emissive: glow ? color : 0, emissiveIntensity: glow }));
  }
  return materials.get(key);
};
const glowing = new Map();
const glowMaterial = (m) => {
  if (!glowing.has(m)) {
    const g = m.clone();
    g.color.lerp(new THREE.Color(COOL), 0.18);
    g.emissive.set(COOL);
    g.emissiveIntensity = 0.1;
    glowing.set(m, g);
  }
  return glowing.get(m);
};
const lines = new Map();
const lineMaterial = (color) => {
  if (!lines.has(color)) lines.set(color, new THREE.LineBasicMaterial({ color }));
  return lines.get(color);
};

/** Builds one item's parts into a group, in the item's local metres. */
class Builder {
  constructor(group) {
    this.group = group;
  }

  add(geometry, side, top, edges) {
    // BoxGeometry's faces: +x, -x, +y (top), -y, +z, -z.
    const mats = top === side ? material(side) : [side, side, top, side, side, side].map((c) => material(c));
    const mesh = new THREE.Mesh(geometry, mats);
    mesh.castShadow = true;
    mesh.receiveShadow = true;
    this.group.add(mesh);
    if (edges) this.group.add(new THREE.LineSegments(new THREE.EdgesGeometry(geometry, 30), lineMaterial(edges)));
    return mesh;
  }

  box(x0, x1, y0, y1, z0, z1, side, top = side, edges = null) {
    if (x1 - x0 < 1e-4 || y1 - y0 < 1e-4 || z1 - z0 < 1e-4) return;
    const g = new THREE.BoxGeometry(x1 - x0, y1 - y0, z1 - z0).translate((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2);
    this.add(g, side, top, edges);
  }

  // NeonPlan rounds a pad's corners; from above a box reads the same.
  pad(x0, x1, y0, y1, z0, z1, side, top = side, _r = 0, edges = null) {
    this.box(x0, x1, y0, y1, z0, z1, side, top, edges);
  }

  /** A solid from rectangle `b` = [x0, x1, z0, z1] at y0 to rectangle `t` at y1. */
  loft(b, t, y0, y1, side, top = side, edges = null) {
    const corners = (r, y) => [[r[0], y, r[2]], [r[1], y, r[2]], [r[1], y, r[3]], [r[0], y, r[3]]];
    const v = [...corners(b, y0), ...corners(t, y1)];
    const quads = [[4, 7, 6, 5], [0, 1, 2, 3], [0, 4, 5, 1], [1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 4, 0]];
    const pos = [];
    for (const [a, b2, c, d] of quads) for (const i of [a, b2, c, a, c, d]) pos.push(...v[i]);
    const g = new THREE.BufferGeometry();
    g.setAttribute("position", new THREE.Float32BufferAttribute(pos, 3));
    g.computeVertexNormals();
    const mesh = this.add(g, top, top, edges);
    mesh.material = material(top);
    mesh.material.side = THREE.DoubleSide;
  }

  cyl(cx, cz, r, y0, y1, side, top = side, n = 10) {
    this.add(new THREE.CylinderGeometry(r, r, y1 - y0, n).translate(cx, (y0 + y1) / 2, cz), side, side);
  }

  lyingCyl(axis, cx, cz, y0, y1, len, dia, side, _cap = side, n = 12) {
    const g = new THREE.CylinderGeometry(dia / 2, dia / 2, len, n).rotateZ(Math.PI / 2);
    if (axis === "z") g.rotateY(Math.PI / 2);
    this.add(g.translate(cx, (y0 + y1) / 2, cz), side, side);
  }
}

function legs(b, w, d, h, t, inset, color = C.metal, taper = false) {
  const x = w / 2 - inset - t;
  const z = d / 2 - inset - t;
  for (const sx of [-1, 1]) {
    for (const sz of [-1, 1]) {
      const cx = sx * x;
      const cz = sz * z;
      if (taper) b.loft([cx - t * 0.3, cx + t * 0.3, cz - t * 0.3, cz + t * 0.3], [cx - t / 2, cx + t / 2, cz - t / 2, cz + t / 2], 0, h, color);
      else b.box(cx - t / 2, cx + t / 2, 0, h, cz - t / 2, cz + t / 2, color);
    }
  }
}

// The models, as NeonPlan builds them.
const MODELS = {
  bed(b, w, d, h) {
    const z0 = -d / 2;
    const z1 = d / 2;
    const x0 = -w / 2;
    const x1 = w / 2;
    const frame = Math.min(0.32, h * 0.36);
    legs(b, w, d, 0.08, 0.06, 0.03, C.wood, true);
    b.box(x0, x1, 0.08, frame, z0 + 0.06, z1, C.wood, C.woodTop, EDGE);
    b.pad(x0 + 0.03, x1 - 0.03, frame, frame + 0.2, z0 + 0.08, z1 - 0.03, C.white, C.whiteTop, 0.03);
    b.box(x0, x1, 0.08, h - 0.05, z0, z0 + 0.07, C.wood, C.woodTop, EDGE);
    b.box(x0, x1, h - 0.05, h, z0, z0 + 0.09, C.wood, C.woodTop, EDGE_FAINT);
    // duvet over the lower two thirds with a folded-back edge, puffy pillows at the head
    const top = frame + 0.2;
    const fold = z0 + (d - 0.1) * 0.36;
    b.pad(x0 + 0.01, x1 - 0.01, top - 0.1, top + 0.05, fold, z1 - 0.01, C.cushion, C.fabricTop, 0.025, EDGE_FAINT);
    b.lyingCyl("x", 0, fold + 0.05, top - 0.02, top + 0.09, w - 0.02, 0.1, C.cushion, C.fabricTop, 8);
    const pillows = w > 1.2 ? 2 : 1;
    const pw = (w - 0.2) / pillows;
    for (let i = 0; i < pillows; i++) {
      const px = x0 + 0.1 + pw * i;
      const pz = z0 + 0.12;
      const pd = Math.min(0.42, d * 0.2);
      const k = 0.1;
      b.loft([px + 0.03 + k, px + pw - 0.03 - k, pz + k * 0.5, pz + pd - k * 0.5], [px + 0.03, px + pw - 0.03, pz, pz + pd], top, top + 0.06, C.whiteTop);
      b.loft([px + 0.03, px + pw - 0.03, pz, pz + pd], [px + 0.03 + k, px + pw - 0.03 - k, pz + k * 0.5, pz + pd - k * 0.5], top + 0.06, top + 0.12, C.whiteTop, C.whiteTop, EDGE_FAINT);
    }
  },

  desk(b, w, d, h) {
    const x0 = -w / 2;
    const x1 = w / 2;
    b.box(x0, x1, h - 0.035, h, -d / 2, d / 2, C.wood, C.woodTop, EDGE);
    b.box(x0, x0 + 0.03, 0, h - 0.035, -d / 2 + 0.03, d / 2 - 0.03, C.metal);
    const dw = Math.min(0.42, w * 0.32);
    b.box(x1 - dw, x1, 0, h - 0.035, -d / 2 + 0.03, d / 2 - 0.02, C.body, C.bodyTop, EDGE);
    // screen
    b.box(-0.3, 0.3, h + 0.08, h + 0.42, -d / 2 + 0.08, -d / 2 + 0.11, C.dark, C.dark, EDGE);
    b.box(-0.03, 0.03, h, h + 0.1, -d / 2 + 0.09, -d / 2 + 0.13, C.metal);
  },

  office_chair(b, w, d, h) {
    const r = Math.min(w, d) / 2;
    // five-star base as two crossed bars and a hub, gas lift, seat and back
    b.box(-r, r, 0.04, 0.08, -0.03, 0.03, C.metal);
    b.box(-0.03, 0.03, 0.04, 0.08, -r, r, C.metal);
    b.cyl(0, 0, 0.06, 0.02, 0.1, C.dark, C.dark, 8);
    b.cyl(0, 0, 0.025, 0.1, 0.44, C.metal, C.metal, 6);
    b.box(-r * 0.75, r * 0.75, 0.44, 0.52, -r * 0.7, r * 0.75, C.fabric, C.cushion, EDGE);
    b.box(-r * 0.7, r * 0.7, 0.58, h, -r * 0.78, -r * 0.62, C.fabric, C.fabricTop, EDGE);
    b.box(-0.03, 0.03, 0.5, 0.62, -r * 0.72, -r * 0.62, C.metal);
  },

  ac_unit(b, w, d, h) {
    const y0 = AC_Y;
    b.box(-w / 2, w / 2, y0 + 0.07, y0 + h, -d / 2, d / 2, C.white, C.whiteTop, EDGE);
    b.box(-w / 2, w / 2, y0, y0 + 0.07, -d / 2, d / 2 - 0.05, C.white, C.white, EDGE);
    b.box(-w / 2 + 0.04, w / 2 - 0.04, y0 + 0.012, y0 + 0.06, d / 2 - 0.05, d / 2 - 0.02, C.dark);
  },
};

// The room's furniture: type, centre (plan units), size in metres [w, d, h], turn in degrees, and
// the spot it belongs to. Desks stand against the top and bottom walls, the bed against the right.
// The bed's head is at its -z, so 90° puts the pillows at the right end.
export const FURNITURE = [
  { type: "desk", at: [17, 8.5], size: [1.5, 0.65, 0.75], rotation: 0, spot: "my_desk" },
  { type: "office_chair", at: [17, 22], size: [0.6, 0.6, 1.05], rotation: 180, spot: "my_desk" },
  { type: "desk", at: [13.5, 81.5], size: [1.15, 0.6, 0.75], rotation: 180, spot: "wife_desk" },
  { type: "office_chair", at: [13.5, 68.5], size: [0.6, 0.6, 1.05], rotation: 0, spot: "wife_desk" },
  { type: "bed", at: [43.1, 44.7], size: [1.3, 2.2, 0.9], rotation: 90, spot: "bed" },
  { type: "ac_unit", at: [33.5, 86.8], size: [0.9, 0.22, 0.3], rotation: 180, ac: true },
];
// The ceiling lights: across the room's middle, set in from the top and bottom walls.
export const CEILING_LIGHTS = { "light.b_office_srinesh": [33.5, 12], "light.b_office_nidu": [33.5, 77.5] };

// A soft round glow, drawn once and shared by every halo.
let haloTexture;
const halo = () => {
  if (!haloTexture) {
    const c = document.createElement("canvas");
    c.width = c.height = 128;
    const g = c.getContext("2d");
    const grad = g.createRadialGradient(64, 64, 0, 64, 64, 64);
    grad.addColorStop(0, "rgba(255,255,255,1)");
    grad.addColorStop(0.4, "rgba(255,255,255,.35)");
    grad.addColorStop(1, "rgba(255,255,255,0)");
    g.fillStyle = grad;
    g.fillRect(0, 0, 128, 128);
    haloTexture = new THREE.CanvasTexture(c);
  }
  return haloTexture;
};
const haloMesh = (w, d, y) => new THREE.Mesh(new THREE.PlaneGeometry(w, d).rotateX(-Math.PI / 2).translate(0, y, 0),
  new THREE.MeshBasicMaterial({ map: halo(), transparent: true, depthWrite: false, blending: THREE.AdditiveBlending }));

/**
 * The room on a canvas: build once, then `draw(width, look)` whenever the size or what it shows
 * changes. `look` = { acOn, spots: the spots being cooled, lights: { entity: [r, g, b] | null } }.
 */
export class Room3D {
  constructor() {
    this.renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    this.canvas = this.renderer.domElement;
    this.scene = new THREE.Scene();
    const [w, d] = ROOM;
    // Straight down on the room, screen up = -z, so plan x/y map to world x/z.
    this.camera = new THREE.OrthographicCamera(0, w, 0, -d, 0.1, 20);
    this.camera.position.set(0, 10, 0);
    this.camera.up.set(0, 0, -1);
    this.camera.lookAt(0, 0, 0);
    this.scene.add(new THREE.HemisphereLight(0xb8c6ff, 0x1a1e26, 2.2));
    // Nearly overhead, so every piece throws a short shadow to the lower right.
    const sun = new THREE.DirectionalLight(0xffffff, 1.6);
    sun.position.set(w / 2 - 1.2, 8, d / 2 - 1.6);
    sun.target.position.set(w / 2, 0, d / 2);
    sun.castShadow = true;
    sun.shadow.mapSize.set(2048, 2048);
    Object.assign(sun.shadow.camera, { left: -4, right: 4, top: 4, bottom: -4, near: 1, far: 15 });
    sun.shadow.radius = 4;
    this.scene.add(sun, sun.target);
    this.build();
  }

  build() {
    const [w, d] = ROOM;
    const floor = new THREE.Mesh(new THREE.PlaneGeometry(w, d).rotateX(-Math.PI / 2).translate(w / 2, 0, d / 2), material(0x14181f));
    floor.receiveShadow = true;
    this.scene.add(floor);
    // Walls, with the door's gap on the right wall from 6 to 18 units. From above only their tops
    // show, so they stay low and throw no long shadows.
    const wall = (x0, x1, z0, z1) => new Builder(this.scene).box(x0, x1, 0, 0.25, z0, z1, 0x2c323b, 0x3a414b);
    const door = [6 * UNIT, 18 * UNIT];
    wall(0, w, 0, WALL);
    wall(0, w, d - WALL, d);
    wall(0, WALL, 0, d);
    wall(w - WALL, w, 0, door[0]);
    wall(w - WALL, w, door[1], d);
    // the door leaf, open into the room
    new Builder(this.scene).box(w - WALL - (door[1] - door[0]), w - WALL, 0, 0.2, door[0], door[0] + 0.04, 0x232a33, 0x2f3742);
    this.acGlow = [];
    // Each spot's meshes and edges with their own materials, to swap for the glowing ones, and the
    // pool of light under it.
    this.spots = {};
    for (const f of FURNITURE) {
      const group = new THREE.Group();
      MODELS[f.type](new Builder(group), ...f.size);
      if (f.spot) {
        const spot = (this.spots[f.spot] ??= { parts: [], halos: [] });
        group.traverse((o) => o.material && spot.parts.push([o, o.material]));
        const pool = haloMesh(f.size[0] + 0.9, f.size[1] + 0.9, 0.01);
        pool.material.color.set(COOL);
        pool.material.opacity = 0.55;
        group.add(pool);
        spot.halos.push(pool);
      }
      group.rotation.y = (-f.rotation * Math.PI) / 180;
      group.position.set(f.at[0] * UNIT, 0, f.at[1] * UNIT);
      if (f.ac) {
        // its front strip glows while the AC runs
        const strip = new THREE.Mesh(new THREE.BoxGeometry(f.size[0] - 0.08, 0.02, 0.03).translate(0, AC_Y + f.size[2] + 0.01, f.size[1] / 2 - 0.03), material(0x7cc7ff, 1));
        group.add(strip);
        this.acGlow.push(strip);
      }
      this.scene.add(group);
    }
    // A flat round fitting on the ceiling; when on, its face, a halo around it and a lamp under it
    // take the light's colour.
    this.lights = {};
    for (const [entity, [x, z]] of Object.entries(CEILING_LIGHTS)) {
      const group = new THREE.Group();
      group.position.set(x * UNIT, 0, z * UNIT);
      const b = new Builder(group);
      b.cyl(0, 0, 0.2, CEILING_Y - 0.04, CEILING_Y, 0x2a313b, 0x2a313b, 32);
      // A fitting on the ceiling throws no shadow worth drawing from straight above.
      group.traverse((o) => (o.castShadow = false));
      const face = new THREE.Mesh(new THREE.CircleGeometry(0.16, 32).rotateX(-Math.PI / 2).translate(0, CEILING_Y + 0.001, 0),
        new THREE.MeshBasicMaterial({ color: FITTING }));
      const glow = haloMesh(1.6, 1.6, CEILING_Y - 0.05);
      const lamp = new THREE.PointLight(0xffffff, 0, 4, 1.6);
      lamp.position.set(0, CEILING_Y - 0.3, 0);
      group.add(face, glow, lamp);
      this.scene.add(group);
      this.lights[entity] = { face, glow, lamp };
    }
  }

  draw(width, { acOn, spots = [], lights = {} }) {
    const height = Math.round((width * ROOM[1]) / ROOM[0]);
    this.renderer.setPixelRatio(window.devicePixelRatio || 1);
    this.renderer.setSize(width, height, false);
    for (const g of this.acGlow) g.visible = acOn;
    for (const [key, spot] of Object.entries(this.spots)) {
      const on = spots.includes(key);
      for (const [o, m] of spot.parts) {
        if (o.isLineSegments) o.material = on ? lineMaterial(COOL) : m;
        else o.material = on ? (Array.isArray(m) ? m.map(glowMaterial) : glowMaterial(m)) : m;
      }
      for (const h of spot.halos) h.visible = on;
    }
    for (const [entity, { face, glow, lamp }] of Object.entries(this.lights)) {
      const rgb = lights[entity];
      glow.visible = !!rgb;
      lamp.intensity = rgb ? 6 : 0;
      if (rgb) {
        const color = new THREE.Color().setRGB(...rgb.map((v) => v / 255), THREE.SRGBColorSpace);
        face.material.color.copy(color);
        glow.material.color.copy(color);
        lamp.color.copy(color);
      } else {
        face.material.color.set(FITTING);
      }
    }
    this.renderer.render(this.scene, this.camera);
  }
}
