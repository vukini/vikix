(function () {
  'use strict';
  var root = document.documentElement;
  var systemTheme = window.matchMedia('(prefers-color-scheme: dark)');
  function isDark() { return root.dataset.theme ? root.dataset.theme === 'dark' : systemTheme.matches; }
  function paint() { document.getElementById('themeName').textContent = isDark() ? 'Light mode' : 'Dark mode'; }
  try {
    var saved = localStorage.getItem('vikix-theme');
    if (saved === 'light' || saved === 'dark') root.dataset.theme = saved;
  } catch (_) { /* A blocked storage API should not stop the page. */ }
  document.getElementById('themeBtn').addEventListener('click', function () {
    root.dataset.theme = isDark() ? 'light' : 'dark';
    try { localStorage.setItem('vikix-theme', root.dataset.theme); } catch (_) {}
    paint();
  });
  systemTheme.addEventListener('change', paint);
  paint();

  var examples = [
    '<p class="example-title">Your next project: a reading app</p><div class="example-task"><span class="task-status">Working</span><h3>Build the reading list</h3><p>A worker develops the feature in its own project copy.</p></div><div class="example-task"><span class="task-status">Working</span><h3>Explore import formats</h3><p>A second worker researches options for you to review.</p></div><div class="example-you">You → working on the design</div>',
    '<p class="example-title">A decision with its context</p><div class="example-task"><span class="task-status">Needs you</span><h3>How should duplicate books work?</h3><p>The reading-list worker asks whether to keep a second copy or update the existing entry.</p></div><div class="example-task"><span class="task-status">Working</span><h3>Explore import formats</h3><p>The research continues while you consider the question.</p></div><div class="example-you">You → decide once, keep the answer with the task</div>',
    '<p class="example-title">The work comes back for review</p><div class="example-task"><span class="task-status">Review</span><h3>A reading list you can try</h3><p>Inspect the changes, the reported checks and any known limitations before accepting the work.</p></div><div class="example-task"><span class="task-status">Review</span><h3>Import options, with trade-offs</h3><p>Read the findings and choose what to build next.</p></div><div class="example-you">You → review the result and set the next direction</div>'
  ];
  document.querySelectorAll('[data-step]').forEach(function (button) {
    button.addEventListener('click', function () {
      document.querySelectorAll('[data-step]').forEach(function (other) { other.setAttribute('aria-pressed', String(other === button)); });
      document.getElementById('workflowContent').innerHTML = examples[Number(button.dataset.step)];
    });
  });
  document.querySelectorAll('[data-copy]').forEach(function (button) {
    button.addEventListener('click', function () {
      var content = document.getElementById(button.dataset.copy);
      function feedback(message) { button.textContent = message; setTimeout(function () { button.textContent = 'Copy'; }, 1800); }
      function select() {
        var range = document.createRange(); range.selectNodeContents(content);
        var selection = window.getSelection(); selection.removeAllRanges(); selection.addRange(range);
        feedback('Selected');
      }
      if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(content.textContent).then(function () { feedback('Copied'); }, select);
      else select();
    });
  });
})();
