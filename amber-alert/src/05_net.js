/* ================= СЕТЬ: транспорты (PeerJS по коду, ручные коды WebRTC, вкладки) ================= */
// Модель: хост-авторитарный. Хост считает мир (двери, свет, угрозы, трансляции), клиенты шлют
// свою позицию и действия. Все сообщения — JSON-объекты {t:'тип', ...}.
const NET_PREFIX = 'amberalert-fanremake-v1-';
const ICE = [
  { urls: ['stun:stun.l.google.com:19302', 'stun:stun1.l.google.com:19302'] },
  { urls: 'stun:global.stun.twilio.com:3478' },
  // бесплатный публичный TURN (если оператор связи режет прямые соединения). Может быть недоступен — тогда просто игнорируется.
  { urls: ['turn:openrelay.metered.ca:80', 'turn:openrelay.metered.ca:443', 'turn:openrelay.metered.ca:443?transport=tcp'], username: 'openrelayproject', credential: 'openrelayproject' },
];
const CODE_ABC = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
function makeRoomCode() { let s = ''; for (let i = 0; i < 5; i++) s += CODE_ABC[(Math.random() * CODE_ABC.length) | 0]; return s; }

class Emitter { constructor() { this.ev = {}; } on(e, f) { (this.ev[e] || (this.ev[e] = [])).push(f); return this; } emit(e, ...a) { (this.ev[e] || []).forEach(f => { try { f(...a); } catch (err) { console.error(err); } }); } }

/* ---- 1. PeerJS: комната по короткому коду (нужен интернет) ---- */
class PeerTransport extends Emitter {
  constructor() { super(); this.conns = {}; this.kind = 'peer'; }
  opts() {
    const o = { debug: 0, config: { iceServers: ICE } };
    if (QS.get('peerhost')) { o.host = QS.get('peerhost'); o.port = +(QS.get('peerport') || 9000); o.path = QS.get('peerpath') || '/'; o.secure = QS.get('peersecure') === '1'; }
    return o;
  }
  host(code) {
    return new Promise((res, rej) => {
      if (!window.peerjs) return rej(new Error('nolib'));
      const p = this.peer = new peerjs.Peer(NET_PREFIX + code, this.opts()); let ok = false;
      const to = setTimeout(() => { if (!ok) rej(new Error('timeout')); }, 15000);
      p.on('open', id => { ok = true; clearTimeout(to); this.id = id; res(id); });
      p.on('error', e => { if (!ok) { clearTimeout(to); rej(e); } else this.emit('error', e); });
      p.on('connection', c => this.wire(c));
      p.on('disconnected', () => { if (!p.destroyed) setTimeout(() => { try { p.reconnect(); } catch (_) { } }, 1000); });
    });
  }
  join(code) {
    return new Promise((res, rej) => {
      if (!window.peerjs) return rej(new Error('nolib'));
      const p = this.peer = new peerjs.Peer(undefined, this.opts()); let ok = false;
      const to = setTimeout(() => { if (!ok) rej(new Error('timeout')); }, 20000);
      p.on('open', id => { this.id = id; const c = p.connect(NET_PREFIX + code.toUpperCase(), { reliable: true, serialization: 'json' }); this.wire(c, peerId => { ok = true; clearTimeout(to); res(peerId); }); });
      p.on('error', e => { if (!ok) { clearTimeout(to); rej(e); } else this.emit('error', e); });
    });
  }
  wire(c, onOpen) {
    c.on('open', () => { this.conns[c.peer] = c; this.emit('peer', c.peer); onOpen && onOpen(c.peer); });
    c.on('data', d => this.emit('msg', c.peer, d));
    c.on('close', () => { if (this.conns[c.peer]) { delete this.conns[c.peer]; this.emit('leave', c.peer); } });
    c.on('error', e => console.warn('conn error', e));
  }
  send(id, m) { const c = this.conns[id]; if (c && c.open) try { c.send(m); } catch (e) { console.warn(e); } }
  broadcast(m, except) { for (const id in this.conns) if (id !== except) this.send(id, m); }
  close() { try { this.peer && this.peer.destroy(); } catch (_) { } this.conns = {}; }
}

/* ---- 2. Ручные коды: без сервера-посредника, обмен двумя кодами через мессенджер ---- */
async function packSDP(desc) {
  const json = JSON.stringify({ t: desc.type, s: desc.sdp });
  if (window.CompressionStream) {
    const cs = new Blob([json]).stream().pipeThrough(new CompressionStream('deflate-raw'));
    const buf = new Uint8Array(await new Response(cs).arrayBuffer()); let bin = ''; for (const b of buf) bin += String.fromCharCode(b);
    return 'AA1z' + btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  }
  return 'AA1j' + btoa(unescape(encodeURIComponent(json)));
}
async function unpackSDP(code) {
  code = code.trim().replace(/\s+/g, '');
  if (code.startsWith('AA1z')) {
    const b64 = code.slice(4).replace(/-/g, '+').replace(/_/g, '/'), bin = atob(b64 + '==='.slice((b64.length + 3) % 4)), u = new Uint8Array(bin.length); for (let i = 0; i < bin.length; i++) u[i] = bin.charCodeAt(i);
    const ds = new Blob([u]).stream().pipeThrough(new DecompressionStream('deflate-raw')); const o = JSON.parse(await new Response(ds).text()); return { type: o.t, sdp: o.s };
  }
  if (code.startsWith('AA1j')) { const o = JSON.parse(decodeURIComponent(escape(atob(code.slice(4))))); return { type: o.t, sdp: o.s }; }
  throw new Error('badcode');
}
function iceDone(pc) { return new Promise(r => { if (pc.iceGatheringState === 'complete') return r(); const f = () => { if (pc.iceGatheringState === 'complete') { pc.removeEventListener('icegatheringstatechange', f); r(); } }; pc.addEventListener('icegatheringstatechange', f); setTimeout(r, 4000); }); }
class ManualTransport extends Emitter {
  constructor() { super(); this.conns = {}; this.kind = 'manual'; this.n = 0; this.id = 'host'; }
  wireDC(dc, peerId) {
    dc.onopen = () => { this.conns[peerId] = dc; this.emit('peer', peerId); };
    dc.onmessage = e => { try { this.emit('msg', peerId, JSON.parse(e.data)); } catch (_) { } };
    dc.onclose = () => { if (this.conns[peerId]) { delete this.conns[peerId]; this.emit('leave', peerId); } };
  }
  // хост: создать приглашение. Возвращает {code, accept(answerCode)}
  async invite() {
    const pc = new RTCPeerConnection({ iceServers: ICE }), peerId = 'm' + (++this.n), dc = pc.createDataChannel('game', { ordered: true });
    this.wireDC(dc, peerId);
    await pc.setLocalDescription(await pc.createOffer()); await iceDone(pc);
    const code = await packSDP(pc.localDescription);
    return { code, accept: async ans => { await pc.setRemoteDescription(await unpackSDP(ans)); } };
  }
  // клиент: принять приглашение, вернуть ответный код
  async answer(code, onOpen) {
    const pc = new RTCPeerConnection({ iceServers: ICE }); this.id = 'c' + makeRoomCode();
    pc.ondatachannel = e => { this.wireDC(e.channel, 'host'); e.channel.addEventListener('open', () => onOpen && onOpen('host')); };
    await pc.setRemoteDescription(await unpackSDP(code)); await pc.setLocalDescription(await pc.createAnswer()); await iceDone(pc);
    return packSDP(pc.localDescription);
  }
  send(id, m) { const c = this.conns[id]; if (c && c.readyState === 'open') c.send(JSON.stringify(m)); }
  broadcast(m, except) { for (const id in this.conns) if (id !== except) this.send(id, m); }
  close() { for (const id in this.conns) try { this.conns[id].close(); } catch (_) { } this.conns = {}; }
}

/* ---- 3. Вкладки одного браузера (BroadcastChannel) — для проверки и игры в двух окнах ---- */
class TabTransport extends Emitter {
  constructor() { super(); this.conns = {}; this.kind = 'tab'; this.id = 't' + makeRoomCode(); }
  open(code, asHost) {
    this.bc = new BroadcastChannel('amberfan-' + code); this.isHost = asHost;
    this.bc.onmessage = e => {
      const m = e.data; if (m.to && m.to !== this.id) return; if (m.from === this.id) return;
      if (m.k === 'hello' && this.isHost) { this.conns[m.from] = 1; this.bc.postMessage({ k: 'welcome', from: this.id, to: m.from }); this.emit('peer', m.from); }
      else if (m.k === 'welcome' && !this.isHost) { this.conns[m.from] = 1; this.hostId = m.from; this.emit('peer', m.from); this._res && this._res(m.from); }
      else if (m.k === 'msg' && this.conns[m.from]) this.emit('msg', m.from, m.d);
      else if (m.k === 'bye' && this.conns[m.from]) { delete this.conns[m.from]; this.emit('leave', m.from); }
    };
    addEventListener('beforeunload', () => this.bc && this.bc.postMessage({ k: 'bye', from: this.id }));
    if (!asHost) return new Promise((res, rej) => { this._res = res; this.bc.postMessage({ k: 'hello', from: this.id }); setTimeout(() => rej(new Error('timeout')), 4000); });
    return Promise.resolve(this.id);
  }
  send(id, m) { if (this.conns[id]) this.bc.postMessage({ k: 'msg', from: this.id, to: id, d: m }); }
  broadcast(m, except) { for (const id in this.conns) if (id !== except) this.send(id, m); }
  close() { try { this.bc.postMessage({ k: 'bye', from: this.id }); this.bc.close(); } catch (_) { } this.conns = {}; }
}

/* ---- сессия поверх транспорта ---- */
const NET = {
  role: 'solo',          // solo | host | client
  t: null, hostPeer: null, code: '', ping: 0,
  start(role, t) { this.role = role; this.t = t; if (!t) return;
    t.on('msg', (peer, m) => this.role === 'host' ? GAME.hostMsg(m, peer) : GAME.clientMsg(m));
    t.on('peer', peer => { if (this.role === 'client') this.hostPeer = peer; else GAME.peerJoined(peer); });
    t.on('leave', peer => this.role === 'host' ? GAME.peerLeft(peer) : GAME.lostHost());
  },
  // клиент → хост (у хоста — напрямую в обработчик)
  toHost(m) { if (this.role === 'client') this.t && this.t.send(this.hostPeer, m); else GAME.hostMsg(m, null); },
  // хост → все клиенты (и себе как клиенту)
  toAll(m, alsoSelf = true) { if (this.role === 'host' && this.t) this.t.broadcast(m); if (alsoSelf) GAME.clientMsg(m); },
  toPeer(peer, m) { if (peer == null) GAME.clientMsg(m); else this.t && this.t.send(peer, m); },
  stop() { if (this.t) this.t.close(); this.t = null; this.role = 'solo'; this.hostPeer = null; },
};
function netErrorText(e) {
  const t = e && (e.type || e.message || String(e));
  if (t === 'peer-unavailable') return 'Комната не найдена. Проверь код.';
  if (t === 'unavailable-id') return 'Такой код уже занят. Попробуй ещё раз.';
  if (t === 'network' || t === 'server-error' || t === 'socket-error' || t === 'socket-closed') return 'Нет связи с сервером комнат. Проверь интернет или используй «Коды-приглашения».';
  if (t === 'browser-incompatible' || t === 'nolib') return 'Браузер не поддерживает онлайн (WebRTC). Попробуй Chrome.';
  if (t === 'timeout') return 'Не удалось подключиться (время вышло). Попробуй «Коды-приглашения».';
  if (t === 'badcode') return 'Код не подходит. Скопируй его целиком.';
  return 'Ошибка сети: ' + t;
}
