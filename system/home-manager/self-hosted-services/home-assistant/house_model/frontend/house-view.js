// The 3D house: floors, walls and room slabs built from a plan, with an HTML marker per device
// projected over the canvas each frame. Markers are plain elements so they stay crisp and
// easy to tap on a phone. The look comes from a theme; state comes from update(hass).

import * as THREE from "./vendor/three.module.min.js";
import { OrbitControls } from "./vendor/OrbitControls.js";

const WALL_T = 0.12;
const SLAB_T = 0.12;
const VEHICLES = ["car", "bike"];
// Block models of the parked vehicles, as [width, height, length, lift, offset] boxes.
const VEHICLE_SHAPES = {
  car: [
    [1.8, 0.6, 4.2, 0.45, 0],
    [1.6, 0.5, 2.2, 1, -0.2],
  ],
  bike: [
    [0.35, 0.55, 1.9, 0.5, 0],
    [0.45, 0.3, 0.7, 0.9, -0.2],
  ],
};

export const isOn = (state) => ["on", "open", "heat", "cool", "dry", "fan_only", "auto", "heat_cool"].includes(state);

export function deviceActive(device, stateObj) {
  if (!stateObj) return false;
  if (VEHICLES.includes(device.kind)) return Number(stateObj.state) > 0;
  if (device.kind === "camera") return stateObj.state !== "unavailable";
  return isOn(stateObj.state);
}

export class HouseView {
  constructor(container, plan, theme, { onTap, markerContent }) {
    this.plan = plan;
    this.theme = theme;
    this.onTap = onTap;
    this.markerContent = markerContent;
    this.visibleFloor = "all";
    this.container = container;

    this.renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    container.appendChild(this.renderer.domElement);

    this.overlay = document.createElement("div");
    this.overlay.className = "markers";
    container.appendChild(this.overlay);

    this.scene = new THREE.Scene();
    const cx = 5;
    const cy = 4.5;
    this.camera = new THREE.PerspectiveCamera(theme.fov ?? 30, 1, 0.1, 200);
    this.camera.position.set(cx + (theme.view?.[0] ?? 14), theme.view?.[1] ?? 20, cy + (theme.view?.[2] ?? 22));
    this.controls = new OrbitControls(this.camera, this.renderer.domElement);
    this.controls.target.set(cx, 1.5, cy);
    this.controls.enableDamping = true;
    this.controls.maxPolarAngle = Math.PI * 0.45;
    this.controls.minDistance = 8;
    this.controls.maxDistance = 60;
    this.controls.enablePan = false;

    this.scene.add(new THREE.HemisphereLight(theme.sky, theme.groundLight, theme.ambient ?? 1.6));
    const sun = new THREE.DirectionalLight(0xffffff, theme.sun ?? 1.4);
    sun.position.set(-8, 20, 12);
    sun.castShadow = true;
    sun.shadow.mapSize.set(1024, 1024);
    Object.assign(sun.shadow.camera, { left: -15, right: 15, top: 15, bottom: -15 });
    this.scene.add(sun);

    this.floorGroups = {};
    this.roomGlow = {};
    this.markers = [];
    this.build();

    this.resizeObserver = new ResizeObserver(() => this.resize());
    this.resizeObserver.observe(container);
    this.resize();
    const loop = () => {
      this.frame = requestAnimationFrame(loop);
      this.controls.update();
      this.renderer.render(this.scene, this.camera);
      this.placeMarkers();
    };
    loop();
  }

  build() {
    const t = this.theme;
    const slabMat = new THREE.MeshStandardMaterial({ color: t.slab, roughness: 0.95 });
    const outdoorMat = new THREE.MeshStandardMaterial({ color: t.outdoor, roughness: 1 });
    const wallMat = new THREE.MeshStandardMaterial({
      color: t.wall,
      roughness: 0.9,
      transparent: t.wallOpacity < 1,
      opacity: t.wallOpacity,
    });
    const edgeMat = new THREE.LineBasicMaterial({ color: t.edge, transparent: true, opacity: t.edgeOpacity ?? 1 });

    const ground = new THREE.Mesh(new THREE.PlaneGeometry(80, 80), new THREE.ShadowMaterial({ opacity: t.shadow ?? 0.12 }));
    ground.rotation.x = -Math.PI / 2;
    ground.position.y = -0.01;
    ground.receiveShadow = true;
    this.scene.add(ground);

    for (const floor of this.plan.floors) {
      const group = new THREE.Group();
      this.floorGroups[floor.id] = group;
      this.scene.add(group);
      for (const room of this.plan.rooms.filter((r) => r.floor === floor.id)) {
        const slab = new THREE.Mesh(new THREE.BoxGeometry(room.w, SLAB_T, room.h), room.outdoor ? outdoorMat : slabMat);
        slab.position.set(room.x + room.w / 2, floor.elevation + SLAB_T / 2, room.y + room.h / 2);
        slab.receiveShadow = true;
        group.add(slab);
        if (t.edges) group.add(this.edges(slab, edgeMat));

        // A flat warm patch on the floor that lights up with the room's lights.
        const glowMat = new THREE.MeshBasicMaterial({ color: t.lightOn, transparent: true, opacity: 0, depthWrite: false });
        const glow = new THREE.Mesh(new THREE.PlaneGeometry(room.w - 0.2, room.h - 0.2), glowMat);
        glow.rotation.x = -Math.PI / 2;
        glow.position.set(room.x + room.w / 2, floor.elevation + SLAB_T + 0.01, room.y + room.h / 2);
        group.add(glow);
        this.roomGlow[room.id] = glow;

        if (room.outdoor) continue;
        const wh = floor.height * (t.wallHeight ?? 0.42);
        const walls = [
          [room.x + room.w / 2, room.y, room.w, WALL_T],
          [room.x + room.w / 2, room.y + room.h, room.w, WALL_T],
          [room.x, room.y + room.h / 2, WALL_T, room.h],
          [room.x + room.w, room.y + room.h / 2, WALL_T, room.h],
        ];
        for (const [x, z, w, d] of walls) {
          const wall = new THREE.Mesh(new THREE.BoxGeometry(w, wh, d), wallMat);
          wall.position.set(x, floor.elevation + SLAB_T + wh / 2, z);
          wall.castShadow = true;
          wall.receiveShadow = true;
          group.add(wall);
          if (t.edges) group.add(this.edges(wall, edgeMat));
        }
      }
    }

    for (const device of this.plan.devices) {
      const room = this.plan.rooms.find((r) => r.id === device.room);
      const floor = this.plan.floors.find((f) => f.id === room.floor);
      const el = document.createElement("button");
      el.className = `marker kind-${device.kind}`;
      el.setAttribute("aria-label", device.name);
      el.addEventListener("click", (ev) => {
        ev.stopPropagation();
        this.onTap(device);
      });
      this.overlay.appendChild(el);
      const lift = device.kind === "light" ? 1.1 : 0.5;
      this.markers.push({ device, el, room, pos: new THREE.Vector3(device.x, floor.elevation + lift, device.y) });
    }

    // Each parked vehicle is a simple block model in its spot, shown only while parked.
    this.vehicleMeshes = {};
    const vehicleMat = new THREE.MeshStandardMaterial({ color: t.car, roughness: 0.6 });
    for (const device of this.plan.devices.filter((d) => VEHICLES.includes(d.kind))) {
      const body = new THREE.Group();
      for (const [w, h, l, y, z] of VEHICLE_SHAPES[device.kind]) {
        const box = new THREE.Mesh(new THREE.BoxGeometry(w, h, l), vehicleMat);
        box.position.set(0, y, z);
        box.castShadow = true;
        body.add(box);
        if (t.edges) body.add(this.edges(box, edgeMat));
      }
      body.rotation.y = Math.PI / 2;
      body.position.set(device.x, 0, device.y);
      body.visible = false;
      this.vehicleMeshes[device.entity] = body;
      this.scene.add(body);
    }
  }

  edges(mesh, mat) {
    const lines = new THREE.LineSegments(new THREE.EdgesGeometry(mesh.geometry), mat);
    lines.position.copy(mesh.position);
    lines.rotation.copy(mesh.rotation);
    return lines;
  }

  setFloor(id) {
    this.visibleFloor = id;
    const order = this.plan.floors.map((f) => f.id);
    for (const [fid, group] of Object.entries(this.floorGroups)) {
      group.visible = id === "all" || order.indexOf(fid) <= order.indexOf(id);
    }
    this.placeMarkers();
  }

  update(hass) {
    this.hass = hass;
    const litRooms = {};
    for (const m of this.markers) {
      const st = hass.states[m.device.entity];
      const active = deviceActive(m.device, st);
      m.active = active;
      m.el.classList.toggle("on", active);
      m.el.classList.toggle("unavailable", !st || st.state === "unavailable");
      m.el.innerHTML = this.markerContent(m.device, st, active);
      if (m.device.kind === "light" && active) litRooms[m.device.room] = (litRooms[m.device.room] ?? 0) + 1;
      if (this.vehicleMeshes[m.device.entity]) this.vehicleMeshes[m.device.entity].visible = active;
    }
    for (const [roomId, glow] of Object.entries(this.roomGlow)) {
      const lit = litRooms[roomId] ?? 0;
      const lights = this.plan.devices.filter((d) => d.kind === "light" && d.room === roomId).length || 1;
      glow.material.opacity = lit ? (this.theme.glow ?? 0.35) * (0.5 + (0.5 * lit) / lights) : 0;
    }
  }

  placeMarkers() {
    const rect = this.container.getBoundingClientRect();
    const order = this.plan.floors.map((f) => f.id);
    const v = new THREE.Vector3();
    for (const m of this.markers) {
      const hidden = this.visibleFloor !== "all" && order.indexOf(m.room.floor) > order.indexOf(this.visibleFloor);
      v.copy(m.pos).project(this.camera);
      const x = ((v.x + 1) / 2) * rect.width;
      const y = ((1 - v.y) / 2) * rect.height;
      m.el.style.transform = `translate(${x}px, ${y}px) translate(-50%, -50%)`;
      m.el.style.display = hidden || v.z > 1 ? "none" : "";
    }
  }

  resize() {
    const { width, height } = this.container.getBoundingClientRect();
    if (!width || !height) return;
    this.renderer.setSize(width, height, false);
    this.camera.aspect = width / height;
    // Keep the whole house in frame on narrow phones.
    const portrait = height > width;
    this.camera.zoom = portrait ? (width / height) * 1.15 : Math.min(1.25, width / height / 1.2);
    this.camera.zoom *= this.theme.zoom ?? 1;
    this.camera.updateProjectionMatrix();
  }

  destroy() {
    cancelAnimationFrame(this.frame);
    this.resizeObserver.disconnect();
    this.renderer.dispose();
  }
}
