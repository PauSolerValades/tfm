import * as PIXI from 'pixi.js';
import { gsap } from 'gsap';

// ----------------------------------------------------
// Constants & Configuration
// ----------------------------------------------------
const NODE_RADIUS = 4;
const BASE_COLOR = 0x30363d; // Offline color (gray)
const ONLINE_COLOR = 0x8b949e; // Online color (light gray)
const EDGE_COLOR = 0x21262d;
const EDGE_ALPHA = 0.08;
let EDGE_RENDER_SCALE = 1; // Will be adjusted for performance
const MAX_PARTICLES = 200;       // Cap concurrent particles

let width = window.innerWidth;
let height = window.innerHeight;

// Stats
let stats = {
    activeUsers: 0,
    totalPosts: 0,
    totalReposts: 0
};

// State
let graphData = null;
let eventsData = null;
let nodesMap = new Map(); // id -> { sprite, x, y, online, color }
let edgeCoords = null;   // Float32Array [x1,y1,x2,y2, ...] for all edges
let sampledEdgesMap = new Map(); // source_id -> [{ targetId, x1, y1, x2, y2 }] (sampled)
let edgeSprite = null;  // PIXI.Sprite holding the canvas-rendered edges
let postColors = new Map(); // post_id -> hsl string color
let isPlaying = false;
let currentTime = 0;
let eventIndex = 0; // Current position in the events array
let maxTime = 1;
let playbackSpeed = 1;
let totalUsers = 0;
let particleCount = 0;

// Base container for zoom/pan
let viewport;
let nodesContainer;
let edgesLayer;       // Direct child of stage (not viewport) — replaced on re-render
let particlesContainer;
let appInstance = null;

// Elements
const playPauseBtn = document.getElementById('play-pause-btn');
const progressSlider = document.getElementById('progress');
const speedSlider = document.getElementById('speed');
const speedVal = document.getElementById('speed-val');
const timeDisplay = document.getElementById('time-display');
const histogramCanvas = document.getElementById('histogram-canvas');
const fullHistogramCanvas = document.getElementById('full-histogram-canvas');

const activeUsersEl = document.getElementById('active-users');
const totalPostsEl = document.getElementById('total-posts');
const totalRepostsEl = document.getElementById('total-reposts');

// ----------------------------------------------------
// Initialization
// ----------------------------------------------------
async function init() {
    const app = new PIXI.Application({
        width,
        height,
        backgroundColor: 0x0d1117,
        resolution: window.devicePixelRatio || 1,
        autoDensity: true,
        antialias: true
    });
    
    document.getElementById('app').appendChild(app.view);
    appInstance = app;

    // Containers
    viewport = new PIXI.Container();
    app.stage.addChild(viewport);
    
    // edgesLayer is OUTSIDE viewport — holds the pre-rendered canvas sprite
    edgesLayer = new PIXI.Container();
    app.stage.addChildAt(edgesLayer, 0); // Behind viewport
    
    nodesContainer = new PIXI.Container();
    particlesContainer = new PIXI.Container();
    
    viewport.addChild(nodesContainer);
    viewport.addChild(particlesContainer);

    // Load Data
    console.log("Fetching data...");
    const [graphRes, eventsRes] = await Promise.all([
        fetch('/data/graph.json'),
        fetch('/data/events.json')
    ]);

    graphData = await graphRes.json();
    eventsData = await eventsRes.json();
    
    totalUsers = Object.keys(graphData.nodes).length;
    
    if (eventsData.length > 0) {
        maxTime = eventsData[eventsData.length - 1].time + 10;
        progressSlider.max = maxTime;
    }

    buildGraph();
    setupInteraction(app.view);
    
    // Ticker
    app.ticker.add((delta) => {
        if (isPlaying) {
            // Delta is in frames, assuming ~60fps
            // Advance simulation time. We assume 1 simulation unit per second of real time at 1x speed.
            // 1 / 60 seconds per frame * playbackSpeed
            currentTime += (app.ticker.deltaMS / 1000) * playbackSpeed;
            
            if (currentTime >= maxTime) {
                currentTime = maxTime;
                isPlaying = false;
                playPauseBtn.textContent = 'Play';
            }
            
            progressSlider.value = currentTime;
            updateSimulation();
        }
    });
    
    // UI Setup
    playPauseBtn.addEventListener('click', () => {
        isPlaying = !isPlaying;
        playPauseBtn.textContent = isPlaying ? 'Pause' : 'Play';
    });
    
    progressSlider.addEventListener('input', (e) => {
        currentTime = parseFloat(e.target.value);
        resetSimulationState();
        updateSimulation(true); // fast forward to current time
        updateStatsUI();
        timeDisplay.textContent = `T: ${currentTime.toFixed(1)}s`;
    });
    
    speedSlider.addEventListener('input', (e) => {
        playbackSpeed = parseFloat(e.target.value);
        speedVal.textContent = playbackSpeed.toFixed(1) + 'x';
    });
    
    window.addEventListener('resize', () => {
        width = window.innerWidth;
        height = window.innerHeight;
        app.renderer.resize(width, height);
    });
    
    console.log("Initialized!");
}

// ----------------------------------------------------
// Drawing the Network
// ----------------------------------------------------
function buildGraph() {
    // Determine bounds to center graph
    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
    const nodeEntries = Object.entries(graphData.nodes);
    
    for (const [, pos] of nodeEntries) {
        if (pos.x < minX) minX = pos.x;
        if (pos.y < minY) minY = pos.y;
        if (pos.x > maxX) maxX = pos.x;
        if (pos.y > maxY) maxY = pos.y;
    }
    
    const w = maxX - minX || 1;
    const h = maxY - minY || 1;
    const scale = (Math.min(width / w, height / h) || 1000) * 3;
    const cx = (minX + maxX) / 2;
    const cy = (minY + maxY) / 2;
    
    // Position nodes as Sprites instead of Graphics (much faster batching)
    for (const [idStr, pos] of nodeEntries) {
        const id = parseInt(idStr);
        const sprite = new PIXI.Sprite(PIXI.Texture.WHITE);
        sprite.anchor.set(0.5);
        sprite.width = NODE_RADIUS * 2;
        sprite.height = NODE_RADIUS * 2;
        sprite.tint = BASE_COLOR;
        sprite.x = (pos.x - cx) * scale + width / 2;
        sprite.y = (pos.y - cy) * scale + height / 2;
        
        nodesMap.set(id, { sprite, x: sprite.x, y: sprite.y, online: false, color: BASE_COLOR });
        nodesContainer.addChild(sprite);
    }
    
    // ---- EDGES: Pre-compute all edge coordinates into typed arrays ----
    const totalEdges = graphData.edges.length;
    const ecLen = totalEdges * 4;
    edgeCoords = new Float32Array(ecLen);
    
    // Also sample edges for particle spawning
    const sampleInterval = Math.max(1, Math.floor(totalEdges / 10000));
    
    for (let i = 0; i < totalEdges; i++) {
        const edge = graphData.edges[i];
        const srcNode = nodesMap.get(edge.source);
        const tgtNode = nodesMap.get(edge.target);
        
        if (srcNode && tgtNode) {
            const idx = i * 4;
            edgeCoords[idx] = srcNode.x;
            edgeCoords[idx + 1] = srcNode.y;
            edgeCoords[idx + 2] = tgtNode.x;
            edgeCoords[idx + 3] = tgtNode.y;
            
            // Store sampled edges for particle spawning
            if (i % sampleInterval === 0) {
                if (!sampledEdgesMap.has(edge.source)) {
                    sampledEdgesMap.set(edge.source, []);
                }
                sampledEdgesMap.get(edge.source).push({
                    targetId: edge.target,
                    x1: srcNode.x, y1: srcNode.y,
                    x2: tgtNode.x, y2: tgtNode.y
                });
            }
        }
    }
    
    // Free the full edge array
    graphData.edges = null;
    
    // ---- RENDER EDGES TO CANVAS (batched stroke) ----
    // Create a canvas matching screen size
    const eCanvas = document.createElement('canvas');
    eCanvas.width = Math.ceil(width);
    eCanvas.height = Math.ceil(height);
    const eCtx = eCanvas.getContext('2d');
    
    eCtx.strokeStyle = `rgba(33, 38, 45, ${EDGE_ALPHA})`;
    eCtx.lineWidth = 0.5;
    eCtx.beginPath();
    
    const s = viewport.scale.x;
    const vx = viewport.x;
    const vy = viewport.y;
    
    for (let i = 0; i < ecLen; i += 4) {
        const x1 = edgeCoords[i] * s + vx;
        const y1 = edgeCoords[i + 1] * s + vy;
        const x2 = edgeCoords[i + 2] * s + vx;
        const y2 = edgeCoords[i + 3] * s + vy;
        
        // Skip edges entirely outside viewport
        if ((x1 < -50 && x2 < -50) || (x1 > width + 50 && x2 > width + 50) ||
            (y1 < -50 && y2 < -50) || (y1 > height + 50 && y2 > height + 50)) continue;
        
        eCtx.moveTo(x1, y1);
        eCtx.lineTo(x2, y2);
    }
    
    eCtx.stroke();
    
    // Convert to PIXI.Sprite — placed OUTSIDE viewport (edgesLayer is on stage)
    const tex = PIXI.Texture.from(eCanvas);
    edgeSprite = new PIXI.Sprite(tex);
    edgeSprite.x = 0;
    edgeSprite.y = 0;
    edgesLayer.addChild(edgeSprite);
    
    console.log(`Rendered ${nodesMap.size} nodes, ${totalEdges} edges (Canvas2D batched)`);
}

// ----------------------------------------------------
// Simulation Logic
// ----------------------------------------------------
function updateSimulation(isScrubbing = false) {
    timeDisplay.textContent = `T: ${currentTime.toFixed(1)}s`;
    
    // Process events up to currentTime
    while (eventIndex < eventsData.length && eventsData[eventIndex].time <= currentTime) {
        const ev = eventsData[eventIndex];
        handleEvent(ev, isScrubbing);
        eventIndex++;
    }
    
    if (!isScrubbing) {
        updateStatsUI();
        drawHistogram();
    }
}

function handleEvent(ev, isScrubbing) {
    const node = nodesMap.get(ev.user_id);
    if (!node) return;
    
    if (ev.type === 'start') {
        node.online = true;
        updateNodeColor(node, node.color);
        if (!isScrubbing) stats.activeUsers++;
    } 
    else if (ev.type === 'end') {
        node.online = false;
        node.color = BASE_COLOR;
        updateNodeColor(node, node.color);
        if (!isScrubbing) stats.activeUsers--;
    } 
    else if (ev.type === 'create') {
        if (!postRepostCounts.has(ev.post_id)) {
            postRepostCounts.set(ev.post_id, 0);
            postColors.set(ev.post_id, ev.color);
        }
        if (!isScrubbing) stats.totalPosts++;
        triggerAction(node, ev, isScrubbing);
    }
    else if (ev.type === 'repost') {
        if (!postRepostCounts.has(ev.post_id)) {
            postRepostCounts.set(ev.post_id, 0);
            postColors.set(ev.post_id, ev.color);
        }
        postRepostCounts.set(ev.post_id, postRepostCounts.get(ev.post_id) + 1);
        if (!isScrubbing) stats.totalReposts++;
        triggerAction(node, ev, isScrubbing);
    }
}

function triggerAction(node, ev, isScrubbing) {
    const hexColor = parseHSL(ev.color);
    node.color = hexColor;
    updateNodeColor(node, hexColor);
    
    if (!isScrubbing) {
        pulseNode(node, hexColor);
        
        // Spawn particles along sampled edges to followers (capped)
        const edges = sampledEdgesMap.get(ev.user_id);
        if (edges && particleCount < MAX_PARTICLES) {
            for (const edge of edges) {
                if (particleCount >= MAX_PARTICLES) break;
                spawnParticle(edge.x1, edge.y1, edge.x2, edge.y2, hexColor);
            }
        }
    }
}

function updateNodeColor(node, color) {
    if (node.online) {
        node.sprite.tint = color === BASE_COLOR ? ONLINE_COLOR : color;
        node.sprite.width = NODE_RADIUS * 3;
        node.sprite.height = NODE_RADIUS * 3;
    } else {
        const darkened = color === BASE_COLOR ? BASE_COLOR : darkenColor(color, 0.4);
        node.sprite.tint = darkened;
        node.sprite.width = NODE_RADIUS * 2;
        node.sprite.height = NODE_RADIUS * 2;
    }
}

function resetSimulationState() {
    stats = { activeUsers: 0, totalPosts: 0, totalReposts: 0 };
    particleCount = 0;
    
    // Reset nodes
    for (const [, node] of nodesMap) {
        node.online = false;
        node.color = BASE_COLOR;
        updateNodeColor(node, BASE_COLOR);
    }
    
    // Clear particles
    for (let i = particlesContainer.children.length - 1; i >= 0; i--) {
        const child = particlesContainer.children[i];
        gsap.killTweensOf(child);
        particlesContainer.removeChild(child);
        child.destroy();
    }
    
    // Fast-forward state
    postRepostCounts.clear();
    postColors.clear();
    
    let tempIndex = 0;
    while (tempIndex < eventsData.length && eventsData[tempIndex].time <= currentTime) {
        const ev = eventsData[tempIndex];
        const node = nodesMap.get(ev.user_id);
        
        if (ev.type === 'create') {
            if (!postRepostCounts.has(ev.post_id)) {
                postRepostCounts.set(ev.post_id, 0);
                postColors.set(ev.post_id, ev.color);
            }
            stats.totalPosts++;
        } else if (ev.type === 'repost') {
            if (!postRepostCounts.has(ev.post_id)) {
                postRepostCounts.set(ev.post_id, 0);
                postColors.set(ev.post_id, ev.color);
            }
            postRepostCounts.set(ev.post_id, postRepostCounts.get(ev.post_id) + 1);
            stats.totalReposts++;
        }
        
        if (node) {
            if (ev.type === 'start') {
                node.online = true;
                stats.activeUsers++;
            } else if (ev.type === 'end') {
                node.online = false;
                node.color = BASE_COLOR;
                stats.activeUsers--;
            } else if (ev.type === 'create' || ev.type === 'repost') {
                node.color = parseHSL(ev.color);
            }
        }
        tempIndex++;
    }
    eventIndex = tempIndex;
    
    for (const [, node] of nodesMap) {
        updateNodeColor(node, node.color);
    }
    
    drawHistogram();
}

// ----------------------------------------------------
// Visual Effects
// ----------------------------------------------------
function pulseNode(node, color) {
    const pulse = new PIXI.Graphics();
    pulse.beginFill(color, 0.4);
    pulse.drawCircle(0, 0, NODE_RADIUS);
    pulse.endFill();
    pulse.x = node.x;
    pulse.y = node.y;
    pulse.alpha = 1;
    
    particlesContainer.addChild(pulse);
    
    gsap.to(pulse.scale, { x: 5, y: 5, duration: 0.6, ease: "power2.out" });
    gsap.to(pulse, { alpha: 0, duration: 0.6, ease: "power2.out", onComplete: () => {
        particlesContainer.removeChild(pulse);
        pulse.destroy();
    }});
}

function spawnParticle(x1, y1, x2, y2, color) {
    particleCount++;
    const p = new PIXI.Graphics();
    p.beginFill(color);
    p.drawCircle(0, 0, 1.5);
    p.endFill();
    p.x = x1;
    p.y = y1;
    
    particlesContainer.addChild(p);
    
    const dist = Math.hypot(x2 - x1, y2 - y1);
    const duration = Math.min(1.5, Math.max(0.1, dist / 200));
    
    gsap.to(p, {
        x: x2, 
        y: y2, 
        duration: duration,
        ease: "none",
        onComplete: () => {
            particleCount--;
            particlesContainer.removeChild(p);
            p.destroy();
        }
    });
}

function updateStatsUI() {
    const percentage = totalUsers > 0 ? ((stats.activeUsers / totalUsers) * 100).toFixed(1) : "0.0";
    activeUsersEl.textContent = `Active Users: ${stats.activeUsers} (${percentage}%)`;
    totalPostsEl.textContent = `Total Posts: ${stats.totalPosts}`;
    totalRepostsEl.textContent = `Total Reposts: ${stats.totalReposts}`;
}

function drawHistogram() {
    if (!histogramCanvas || !fullHistogramCanvas) return;
    
    // Get entries, sort by count descending
    const entries = Array.from(postRepostCounts.entries())
        .sort((a, b) => b[1] - a[1]);
        
    if (entries.length === 0) return;
    
    const maxCount = entries[0][1];
    if (maxCount === 0) return; // nothing to draw if highest is 0
    
    const drawToCanvas = (canvas, enforceTopN) => {
        // Resize canvas to physical pixels to keep drawing sharp
        const rect = canvas.getBoundingClientRect();
        if (canvas.width !== rect.width || canvas.height !== rect.height) {
            canvas.width = rect.width;
            canvas.height = rect.height;
        }
        
        const ctx = canvas.getContext('2d');
        const w = canvas.width;
        const h = canvas.height;
        
        // Clear canvas
        ctx.clearRect(0, 0, w, h);
        
        const barsToDraw = enforceTopN ? Math.min(entries.length, 50) : entries.length;
        
        const padding = 5;
        const availableWidth = w - padding * 2;
        const availableHeight = h - padding * 2;
        
        // Divide width evenly
        const barWidth = enforceTopN ? Math.max(1, (availableWidth / barsToDraw) - 1) : (availableWidth / barsToDraw);
        
        ctx.fillStyle = 'rgba(255, 255, 255, 0.1)';
        ctx.fillRect(padding, padding, availableWidth, availableHeight);
        
        for (let i = 0; i < barsToDraw; i++) {
            const [postId, count] = entries[i];
            if (count === 0) continue;
            
            const barHeight = (count / maxCount) * availableHeight;
            
            const x = enforceTopN ? padding + i * (barWidth + 1) : padding + i * barWidth;
            const y = h - padding - barHeight;
            
            // Convert HSL string back to canvas fillStyle
            const colorStr = postColors.get(postId) || '#ffffff';
            ctx.fillStyle = colorStr;
            
            ctx.fillRect(x, y, enforceTopN ? barWidth : Math.max(1, Math.ceil(barWidth)), barHeight);
        }
    };
    
    drawToCanvas(histogramCanvas, true);
    drawToCanvas(fullHistogramCanvas, false);
}

// ----------------------------------------------------
// Utilities
// ----------------------------------------------------
function parseHSL(hslStr) {
    // Basic conversion from hsl(h, s%, l%) to hex
    const match = hslStr.match(/hsl\((\d+),\s*(\d+)%,\s*(\d+)%\)/);
    if (!match) return 0xffffff;
    
    let h = parseInt(match[1]) / 360;
    let s = parseInt(match[2]) / 100;
    let l = parseInt(match[3]) / 100;
    
    let r, g, b;
    if (s === 0) {
        r = g = b = l;
    } else {
        const hue2rgb = (p, q, t) => {
            if (t < 0) t += 1;
            if (t > 1) t -= 1;
            if (t < 1/6) return p + (q - p) * 6 * t;
            if (t < 1/2) return q;
            if (t < 2/3) return p + (q - p) * (2/3 - t) * 6;
            return p;
        };
        const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
        const p = 2 * l - q;
        r = hue2rgb(p, q, h + 1/3);
        g = hue2rgb(p, q, h);
        b = hue2rgb(p, q, h - 1/3);
    }
    return Math.round(r * 255) << 16 | Math.round(g * 255) << 8 | Math.round(b * 255);
}

function darkenColor(hex, factor) {
    const r = (hex >> 16) & 255;
    const g = (hex >> 8) & 255;
    const b = hex & 255;
    return (Math.floor(r * factor) << 16) | (Math.floor(g * factor) << 8) | Math.floor(b * factor);
}

// ----------------------------------------------------
// Interaction (Pan / Zoom)
// ----------------------------------------------------
function setupInteraction(canvas) {
    let isDragging = false;
    let startX = 0, startY = 0;
    let initX = 0, initY = 0;
    
    canvas.addEventListener('mousedown', (e) => {
        isDragging = true;
        startX = e.clientX;
        startY = e.clientY;
        initX = viewport.x;
        initY = viewport.y;
    });
    
    window.addEventListener('mouseup', () => {
        if (isDragging) scheduleEdgeRedraw();
        isDragging = false;
    });
    
    window.addEventListener('mousemove', (e) => {
        if (isDragging) {
            viewport.x = initX + (e.clientX - startX);
            viewport.y = initY + (e.clientY - startY);
        }
    });
    
    canvas.addEventListener('wheel', (e) => {
        e.preventDefault();
        const zoomFactor = 1.1;
        const direction = e.deltaY > 0 ? 1 / zoomFactor : zoomFactor;
        
        const mouseX = e.clientX;
        const mouseY = e.clientY;
        
        const localX = (mouseX - viewport.x) / viewport.scale.x;
        const localY = (mouseY - viewport.y) / viewport.scale.y;
        
        viewport.scale.x *= direction;
        viewport.scale.y *= direction;
        
        viewport.x = mouseX - localX * viewport.scale.x;
        viewport.y = mouseY - localY * viewport.scale.y;
        
        scheduleEdgeRedraw();
    }, { passive: false });
}

let redrawTimer = null;
function scheduleEdgeRedraw() {
    // Debounce: re-render edges 200ms after zoom/pan stops
    if (redrawTimer) clearTimeout(redrawTimer);
    redrawTimer = setTimeout(() => {
        if (!edgeCoords) return;
        
        const eCanvas = document.createElement('canvas');
        eCanvas.width = Math.ceil(width);
        eCanvas.height = Math.ceil(height);
        const eCtx = eCanvas.getContext('2d');
        
        eCtx.strokeStyle = `rgba(33, 38, 45, ${EDGE_ALPHA})`;
        eCtx.lineWidth = 0.5;
        eCtx.beginPath();
        
        const s = viewport.scale.x;
        const vx = viewport.x;
        const vy = viewport.y;
        const len = edgeCoords.length;
        
        for (let i = 0; i < len; i += 4) {
            const x1 = edgeCoords[i] * s + vx;
            const y1 = edgeCoords[i + 1] * s + vy;
            const x2 = edgeCoords[i + 2] * s + vx;
            const y2 = edgeCoords[i + 3] * s + vy;
            
            if ((x1 < -50 && x2 < -50) || (x1 > width + 50 && x2 > width + 50) ||
                (y1 < -50 && y2 < -50) || (y1 > height + 50 && y2 > height + 50)) continue;
            
            eCtx.moveTo(x1, y1);
            eCtx.lineTo(x2, y2);
        }
        
        eCtx.stroke();
        
        // Replace the edge sprite texture
        const tex = PIXI.Texture.from(eCanvas);
        if (edgeSprite) {
            edgeSprite.texture.destroy(true);
            edgeSprite.texture = tex;
        }
    }, 200);

init();
