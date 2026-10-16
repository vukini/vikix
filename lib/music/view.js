'use strict';
const $ = id => document.getElementById(id);
let state, busy = false, polling, lastError = '', queued = [];
const token = location.hash.slice(1);
history.replaceState(null, '', location.pathname);
for (const note of ['-', 'x', ...Array.from({length:9}, (_, i) => ['c','cs','d','eb','e','f','fs','g','gs','a','bb','b'].map(n => n+i)).flat()]) {
  const option = document.createElement('option'); option.value = note; option.textContent = note.toUpperCase(); $('note').append(option);
}
$('note').value = 'a5';
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
  if (state.error) lastError = state.error;
  $('song').textContent = state.song;
  $('status').textContent = lastError || 'Connected · edits arrive at the next bar';
  $('playing').textContent = state.playing ? `Playing · ${state.pattern}` : 'Stopped';
  if (document.activeElement !== $('tempo')) $('tempo').value = state.tempo;
  if (document.activeElement !== $('gain')) $('gain').value = state.gain;
  if (!changed) return;
  const selected = $('pattern').value;
  $('pattern').replaceChildren(...state.patterns.map(p => {
    const option = document.createElement('option'); option.value = p.name; option.textContent = p.name; return option;
  }));
  $('pattern').value = state.patterns.some(p => p.name === selected) ? selected : (state.patterns.some(p => p.name === state.pattern) ? state.pattern : state.patterns[0].name);
  draw();
}
function draw() {
  const pattern = state.patterns.find(p => p.name === $('pattern').value) || state.patterns[0];
  // Show the data the grid represents, without interpreting it as markup or
  // claiming to reproduce the file's comments and whitespace.
  $('subtitle').textContent = `(tempo ${state.tempo})\n(defpattern ${pattern.name} '(${pattern.notes.join(' ')}))`;
  $('grid').replaceChildren(...pattern.notes.map((note, i) => {
    const button = document.createElement('button'); button.className = 'step' + (note === '-' ? '' : ' active');
    button.setAttribute('aria-label', `Step ${i+1}: ${note}`);
    const number = document.createElement('small'); number.textContent = String(i+1).padStart(2, '0');
    const label = document.createElement('strong'); label.textContent = note.toUpperCase(); button.append(number, label);
    button.onclick = () => send({op:'note', revision:state.revision, pattern:pattern.name, step:i, note:note === $('note').value ? '-' : $('note').value});
    return button;
  }));
}
ws.onopen = () => { send({token}); polling = setInterval(() => send({op:'state'}), 700); };
ws.onmessage = event => { busy = false; render(JSON.parse(event.data)); if (queued.length) send(queued.shift()); };
ws.onclose = () => { clearInterval(polling); $('status').textContent = 'Disconnected. Reopen with vikix music web to reconnect.'; };
ws.onerror = () => { $('status').textContent = 'Cannot reach the music session.'; };
$('play').onclick = () => send({op:'play', pattern:$('pattern').value});
$('stop').onclick = () => send({op:'stop'});
$('tempo').onchange = () => state && send({op:'tempo', revision:state.revision, value:Number($('tempo').value)});
$('gain').onchange = () => send({op:'gain', value:Number($('gain').value)});
$('pattern').onchange = draw;
