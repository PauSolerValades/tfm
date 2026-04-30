import * as PIXI from 'pixi.js';
import { gsap } from 'gsap';

// ----------------------------------------------------
// Constants & Configuration
// ----------------------------------------------------
const NODE_RADIUS = 4;
const BASE_COLOR = 0x30363d; // Offline color (gray)
const ONLINE_COLOR = 0x8b949e; // Online color (light gray)
const EDGE_COLOR = 0x21262d;
const EDGE_ALPHA = 0.2;
const ONLINE_EDGE_ALPHA = 0.5;

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
let nodesMap = new Map(); // id -> PIXI.Graphics (Node)
let outgoingEdges = new Map(); // source_id -> array of { targetId, gfx }
let postRepostCounts = new Map(); // post_id -> count
let postColors = new Map(); // post_id -> hsl string color
let isPlaying = false;
let currentTime = 0;
let eventIndex = 0; // Current position in the events array
let maxTime = 1;
let playbackSpeed = 1;
let totalUsers = 0;

// Base container for zoom/pan
let viewport;
let nodesContainer;
let edgesContainer;
let particlesContainer;

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

    // Containers
    viewport = new PIXI.Container();
    app.stage.addChild(viewport);
    
    edgesContainer = new PIXI.Container();
    nodesContainer = new PIXI.Container();
    particlesContainer = new PIXI.Container();
    
    viewport.addChild(edgesContainer);
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
    
    for (const [id, pos] of Object.entries(graphData.nodes)) {
        if (pos.x < minX) minX = pos.x;
        if (pos.y < minY) minY = pos.y;
        if (pos.x > maxX) maxX = pos.x;
        if (pos.y > maxY) maxY = pos.y;
    }
    
    // Scale layout to make nodes more separate.
    // Instead of forcing the entire graph to fit on the screen initially, 
    // we make it larger so nodes aren't as densely packed. Users can zoom out if needed.
    const w = maxX - minX;
    const h = maxY - minY;
    
    // Make the scale 3x larger than fitting to screen, to increase node separation
    const scale = (Math.min(width / w, height / h) || 1000) * 3;
    const cx = (minX + maxX) / 2;
    const cy = (minY + maxY) / 2;
    
    // Position nodes
    for (const [idStr, pos] of Object.entries(graphData.nodes)) {
        const id = parseInt(idStr);
        const node = new PIXI.Graphics();
        node.beginFill(BASE_COLOR);
        node.drawCircle(0, 0, NODE_RADIUS);
        node.endFill();
        
        node.x = (pos.x - cx) * scale + width / 2;
        node.y = (pos.y - cy) * scale + height / 2;
        
        // Save references
        node.userData = { id, online: false, color: BASE_COLOR };
        nodesMap.set(id, node);
        nodesContainer.addChild(node);
        
        outgoingEdges.set(id, []);
    }
    
    // Draw edges
    const linesGfx = new PIXI.Graphics();
    edgesContainer.addChild(linesGfx);
    
    for (const edge of graphData.edges) {
        const sourceId = edge.source;
        const targetId = edge.target;
        
        const sourceNode = nodesMap.get(sourceId);
        const targetNode = nodesMap.get(targetId);
        
        if (sourceNode && targetNode) {
            linesGfx.lineStyle(1, EDGE_COLOR, EDGE_ALPHA);
            linesGfx.moveTo(sourceNode.x, sourceNode.y);
            linesGfx.lineTo(targetNode.x, targetNode.y);
            
            outgoingEdges.get(sourceId).push({
                targetId: targetId,
                x1: sourceNode.x,
                y1: sourceNode.y,
                x2: targetNode.x,
                y2: targetNode.y
            });
        }
    }
    
    console.log(`Rendered ${graphData.nodes.length || nodesMap.size} nodes and ${graphData.edges.length} edges.`);
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
        node.userData.online = true;
        updateNodeColor(node, node.userData.color);
        if (!isScrubbing) stats.activeUsers++;
    } 
    else if (ev.type === 'end') {
        node.userData.online = false;
        node.userData.color = BASE_COLOR; // reset color when offline? Or keep it?
        updateNodeColor(node, node.userData.color);
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
    // Change node color to the post's color
    const hexColor = parseHSL(ev.color); // We need PIXI compatible numeric hex
    node.userData.color = hexColor;
    updateNodeColor(node, hexColor);
    
    if (!isScrubbing) {
        // Animation: Bubble / Pulse
        pulseNode(node, hexColor);
        
        // Spawn particles along edges to followers
        const edges = outgoingEdges.get(ev.user_id);
        if (edges) {
            for (const edge of edges) {
                spawnParticle(edge.x1, edge.y1, edge.x2, edge.y2, hexColor);
            }
        }
    }
}

function updateNodeColor(node, color) {
    node.clear();
    
    if (node.userData.online) {
        // If online, show actual color or online grey
        node.beginFill(color === BASE_COLOR ? ONLINE_COLOR : color);
        node.drawCircle(0, 0, NODE_RADIUS * 1.5); // Slightly larger when online
    } else {
        // Darken color if offline
        const darkened = color === BASE_COLOR ? BASE_COLOR : darkenColor(color, 0.4);
        node.beginFill(darkened);
        node.drawCircle(0, 0, NODE_RADIUS);
    }
    node.endFill();
}

function resetSimulationState() {
    // Reset Stats
    stats = { activeUsers: 0, totalPosts: 0, totalReposts: 0 };
    
    // Reset nodes
    for (const [id, node] of nodesMap.entries()) {
        node.userData.online = false;
        node.userData.color = BASE_COLOR;
        updateNodeColor(node, BASE_COLOR);
    }
    
    // Clear particles
    for (let i = particlesContainer.children.length - 1; i >= 0; i--) {
        const child = particlesContainer.children[i];
        gsap.killTweensOf(child);
        particlesContainer.removeChild(child);
        child.destroy();
    }
    
    // Set event index based on current time
    eventIndex = 0;
    while (eventIndex < eventsData.length && eventsData[eventIndex].time < currentTime) {
        const ev = eventsData[eventIndex];
        // Accumulate state
        if (ev.type === 'start') stats.activeUsers++;
        if (ev.type === 'end') stats.activeUsers--;
        if (ev.type === 'create') stats.totalPosts++;
        if (ev.type === 'repost') stats.totalReposts++;
        
        eventIndex++;
    }
    
    // To accurately recreate state, we actually need to play through from 0 to currentTime silently
    // But since that can be slow, we'll reset stats manually above, but the nodes state requires a fast-forward:
    stats = { activeUsers: 0, totalPosts: 0, totalReposts: 0 };
    postRepostCounts.clear();
    postColors.clear();
    
    for (const [id, node] of nodesMap.entries()) {
        node.userData.online = false;
        node.userData.color = BASE_COLOR;
    }
    
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
        }
        else if (ev.type === 'repost') {
            if (!postRepostCounts.has(ev.post_id)) {
                postRepostCounts.set(ev.post_id, 0);
                postColors.set(ev.post_id, ev.color);
            }
            postRepostCounts.set(ev.post_id, postRepostCounts.get(ev.post_id) + 1);
            stats.totalReposts++;
        }
        
        if (node) {
            if (ev.type === 'start') {
                node.userData.online = true;
                stats.activeUsers++;
            }
            else if (ev.type === 'end') {
                node.userData.online = false;
                node.userData.color = BASE_COLOR;
                stats.activeUsers--;
            }
            else if (ev.type === 'create' || ev.type === 'repost') {
                node.userData.color = parseHSL(ev.color);
            }
        }
        tempIndex++;
    }
    eventIndex = tempIndex;
    
    for (const [id, node] of nodesMap.entries()) {
        updateNodeColor(node, node.userData.color);
    }
    
    drawHistogram();
}

// ----------------------------------------------------
// Visual Effects
// ----------------------------------------------------
function pulseNode(node, color) {
    const pulse = new PIXI.Graphics();
    pulse.beginFill(color, 0.5);
    pulse.drawCircle(0, 0, NODE_RADIUS);
    pulse.endFill();
    pulse.x = node.x;
    pulse.y = node.y;
    
    particlesContainer.addChild(pulse);
    
    gsap.to(pulse.scale, { x: 4, y: 4, duration: 0.8, ease: "power2.out" });
    gsap.to(pulse, { alpha: 0, duration: 0.8, ease: "power2.out", onComplete: () => {
        particlesContainer.removeChild(pulse);
        pulse.destroy();
    }});
}

function spawnParticle(x1, y1, x2, y2, color) {
    const p = new PIXI.Graphics();
    p.beginFill(color);
    p.drawCircle(0, 0, 2);
    p.endFill();
    p.x = x1;
    p.y = y1;
    
    particlesContainer.addChild(p);
    
    // Distance based duration
    const dist = Math.hypot(x2 - x1, y2 - y1);
    const duration = Math.min(2.0, Math.max(0.2, dist / 100)) / playbackSpeed;
    
    gsap.to(p, {
        x: x2, 
        y: y2, 
        duration: duration,
        ease: "none",
        onComplete: () => {
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
    
    window.addEventListener('mouseup', () => isDragging = false);
    
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
        
        // Zoom towards mouse position
        const mouseX = e.clientX;
        const mouseY = e.clientY;
        
        const localX = (mouseX - viewport.x) / viewport.scale.x;
        const localY = (mouseY - viewport.y) / viewport.scale.y;
        
        viewport.scale.x *= direction;
        viewport.scale.y *= direction;
        
        viewport.x = mouseX - localX * viewport.scale.x;
        viewport.y = mouseY - localY * viewport.scale.y;
    }, { passive: false });
}

init();
