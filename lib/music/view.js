'use strict';
const $ = id => document.getElementById(id);
let state, busy = false, polling, lastError = '', queued = [], received = 0;
const token = location.hash.slice(1);
history.replaceState(null, '', location.pathname);
for (const note of ['-', 'x', ...Array.from({length:9}, (_, i) => ['c','cs','d','eb','e','f','fs','g','gs','a','bb','b'].map(n => n+i)).flat()]) {
  const option = document.createElement('option'); option.value = note; option.textContent = note.toUpperCase(); $('note').append(option);
}
$('note').value = 'a5';
for (let slot = 1; slot <= 32; slot++) {
  const option = document.createElement('option'); option.value = slot; option.textContent = slot;
  $('bank-slot').append(option);
}
function assignment() {
  if (!state) return;
  const pad = state.pads.find(p => p.slot === Number($('bank-slot').value));
  $('bank-pattern').value = pad?.pattern || '';
}
$('bank-slot').onchange = assignment;
$('assign').onclick = () => state && send({op:'assign', revision:state.revision,
  slot:Number($('bank-slot').value), pattern:$('bank-pattern').value || null});
const ws = new WebSocket(`ws://${location.host}/socket`);
function send(command) {
  if (ws.readyState !== WebSocket.OPEN) return;
  if (busy) { if (command.op !== 'state' && queued.length < 8) queued.push(command); return; }
  if (command.op !== 'state') lastError = '';
  busy = true; ws.send(JSON.stringify(command));
}
function render(next) {
  const changed = !state || state.revision !== next.revision;
  state = next;
  received = performance.now();
  if (state.error) lastError = state.error;
  $('song').textContent = state.song;
  $('status').textContent = lastError || 'Connected · edits arrive at the next bar';
  $('playing').textContent = state.playing ? `Playing · ${state.pattern}` : 'Stopped';
  if (document.activeElement !== $('tempo')) $('tempo').value = state.tempo;
  if (document.activeElement !== $('gain')) $('gain').value = state.gain;
  if (changed) {
    $('pads').replaceChildren(...state.pads.map(p => {
      const button = document.createElement('button');
      button.textContent = state.bank ? `${p.slot} · ${p.pattern}` : p.pattern;
      button.dataset.pattern = p.pattern; button.dataset.slot = p.slot;
      button.onclick = () => {
        $('pattern').value = p.pattern; draw();
        send({op:'play', slot:p.slot, revision:state.revision});
      };
      return button;
    }));
  }
  for (const pad of $('pads').children) {
    pad.setAttribute('aria-pressed', String(state.playing && pad.dataset.pattern === state.pattern));
  }
  if (!changed) { controls(); return; }
  const empty = document.createElement('option'); empty.value = ''; empty.textContent = 'Unassigned';
  $('bank-pattern').replaceChildren(empty, ...state.patterns.map(p => {
    const option = document.createElement('option'); option.value = p.name; option.textContent = p.name; return option;
  }));
  assignment();
  const selected = $('pattern').value;
  $('pattern').replaceChildren(...state.patterns.map(p => {
    const option = document.createElement('option'); option.value = p.name; option.textContent = p.name; return option;
  }));
  $('pattern').value = state.patterns.some(p => p.name === selected) ? selected : (state.patterns.some(p => p.name === state.pattern) ? state.pattern : state.patterns[0].name);
  draw();
}
function position() {
  const now = state ? state.now + (performance.now() - received) / 1000 : 0;
  const bar = state?.playing && ws.readyState === WebSocket.OPEN &&
    state.pattern === $('pattern').value &&
    state.bars?.find(b => now >= b.start && now < b.start + b.duration);
  const step = bar && bar.steps === $('grid').children.length ?
    (() => {
      const phase = (now - bar.start) / bar.duration * bar.steps;
      const straight = Math.floor(phase);
      return straight % 2 && phase < straight + (bar.swing || 0) ? straight - 1 : straight;
    })() : -1;
  for (const [i, cell] of Array.from($('grid').children).entries()) {
    cell.classList.toggle('current', i === step);
    if (i === step) cell.setAttribute('aria-current', 'step');
    else cell.removeAttribute('aria-current');
  }
  requestAnimationFrame(position);
}
requestAnimationFrame(position);
function controls(force = false) {
  const pattern = state.patterns.find(p => p.name === $('pattern').value) || state.patterns[0];
  for (const [id, value] of [['sound', pattern.sound], ['pattern-gain', pattern.gain], ['swing', pattern.swing]]) {
    if (force || state.error || document.activeElement !== $(id)) $(id).value = value;
  }
  const drum = ['kick', 'snare', 'closed-hat'].includes(pattern.sound);
  for (const option of $('note').options) option.disabled = drum && !['x', '-'].includes(option.value);
  if (drum && !['x', '-'].includes($('note').value)) $('note').value = 'x';
  $('sound-hint').textContent = drum ?
    'X triggers this drum; − rests. Replace pitched notes with X before choosing a drum.' :
    'Notes choose pitch; X plays 220 Hz. Pattern gain multiplies session gain. Swing delays alternate steps; use an even step count.';
}
function draw() {
  const pattern = state.patterns.find(p => p.name === $('pattern').value) || state.patterns[0];
  // Show the data the grid represents, without interpreting it as markup or
  // claiming to reproduce the file's comments and whitespace.
  const options = (pattern.sound !== 'sine' ? ` :sound '${pattern.sound}` : '') +
    (pattern.gain !== 1 ? ` :gain ${pattern.gain}` : '') +
    (pattern.swing !== 0 ? ` :swing ${pattern.swing}` : '');
  $('subtitle').textContent = `(tempo ${state.tempo})\n(defpattern ${pattern.name} '(${pattern.notes.join(' ')})${options})`;
  controls(true);
  $('grid').replaceChildren(...pattern.notes.map((note, i) => {
    const button = document.createElement('button'); button.className = 'step' + (note === '-' ? '' : ' active');
    button.setAttribute('aria-label', `Step ${i+1}: ${note}`);
    const number = document.createElement('small'); number.textContent = String(i+1).padStart(2, '0');
    const label = document.createElement('strong'); label.textContent = note.toUpperCase(); button.append(number, label);
    button.onclick = () => send({op:'note', revision:state.revision, pattern:pattern.name, step:i, note:note === $('note').value ? '-' : $('note').value});
    return button;
  }));
}
ws.onopen = () => { send({token}); polling = setInterval(() => send({op:'state'}), 100); };
ws.onmessage = event => { busy = false; render(JSON.parse(event.data)); if (queued.length) send(queued.shift()); };
ws.onclose = () => {
  clearInterval(polling);
  for (const pad of $('pads').children) pad.setAttribute('aria-pressed', 'false');
  $('playing').textContent = 'Playback status unknown';
  $('status').textContent = 'Disconnected. Reopen with vikix music web to reconnect.';
};
ws.onerror = () => { $('status').textContent = 'Cannot reach the music session.'; };
$('play').onclick = () => send({op:'play', pattern:$('pattern').value});
$('stop').onclick = () => send({op:'stop'});
$('tempo').onchange = () => state && send({op:'tempo', revision:state.revision, value:Number($('tempo').value)});
$('gain').onchange = () => send({op:'gain', value:Number($('gain').value)});
$('pattern').onchange = draw;

for (const op of ['sound', 'pattern-gain', 'swing']) {
  $(op).onchange = () => state && send({op, revision:state.revision,
    pattern:$('pattern').value, value:op === 'sound' ? $(op).value : Number($(op).value)});
}
