let STATE = null;

function tabGroup(containerId){
  const root = document.getElementById(containerId);
  root.querySelectorAll('.tab').forEach(t => t.addEventListener('click', () => {
    root.querySelectorAll('.tab').forEach(x => x.classList.remove('active'));
    t.classList.add('active');
    const scope = root.closest('.card') || document;
    scope.querySelectorAll('.tabpane').forEach(p =>
      p.classList.toggle('active', p.dataset.pane === t.dataset.tab));
  }));
}

function log(msg, ok){
  const box = document.getElementById('log');
  if (box.querySelector('.muted')) box.innerHTML = '';
  const el = document.createElement('div');
  el.className = 'log-line ' + (ok ? 'log-ok' : 'log-err');
  el.textContent = (ok ? '✓ ' : '✗ ') + msg;
  box.prepend(el);
}

function badge(status){
  const m = {REGISTERED:'b-reg', WAITLISTED:'b-wait', DROPPED:'b-drop', COMPLETED:'b-comp'};
  return `<span class="badge ${m[status]||''}">${status}</span>`;
}

function fillStudents(sel, list){
  sel.innerHTML = list.map(s =>
    `<option value="${s.student_id}">${s.reg_no} — ${s.name}</option>`).join('');
}
function fillSections(sel, list){
  sel.innerHTML = list.map(s =>
    `<option value="${s.section_id}">${s.section_id} · ${s.course_code} (${s.seats_available}/${s.capacity} free)</option>`).join('');
}

async function refresh(){
  let d;
  try { d = await (await fetch('/api/state')).json(); }
  catch(e){ return; }
  STATE = d;
  const conn = document.getElementById('conn');
  const banner = document.getElementById('banner');
  if (!d.connected){
    conn.className = 'pill pill-bad'; conn.textContent = 'not connected';
    banner.classList.remove('hidden');
    banner.innerHTML = `<b>Cannot reach Oracle</b> (${d.user}@${d.dsn}). Start Oracle XE and the schema, then Refresh. &nbsp;<span class="small">${(d.error||'').slice(0,160)}</span>`;
    return;
  }
  conn.className = 'pill pill-ok'; conn.textContent = 'connected';
  banner.classList.add('hidden');

  document.getElementById('k-sections').textContent = d.kpis.sections;
  document.getElementById('k-students').textContent = d.kpis.students;
  document.getElementById('k-wait').textContent    = d.kpis.waitlisted;
  document.getElementById('k-util').textContent    = d.kpis.avg_util + '%';

  // sections
  document.querySelector('#sections tbody').innerHTML = d.sections.map(s => {
    const pct = s.utilization_pct || 0;
    const col = pct >= 100 ? 'var(--red)' : pct >= 80 ? 'var(--amber)' : 'var(--teal)';
    const free = s.seats_available <= 0
      ? `<span class="full">FULL</span>`
      : `${s.enrolled_count}/${s.capacity}`;
    return `<tr>
      <td>${s.section_id}</td>
      <td><b>${s.course_code}</b><br><span class="muted small">${s.title}</span></td>
      <td>${s.faculty}</td>
      <td>${free}</td>
      <td><div class="bar-row"><div class="bar"><i style="width:${Math.min(pct,100)}%;background:${col}"></i></div><span class="bar-pct">${pct}%</span></div></td>
    </tr>`;
  }).join('');

  // students
  document.querySelector('#students tbody').innerHTML = d.students.map(s =>
    `<tr><td>${s.student_id}</td><td>${s.reg_no}</td><td>${s.name}</td><td>${s.program_name}</td><td><b>${s.cgpa}</b></td></tr>`).join('');

  // waitlist
  document.querySelector('#waitlist tbody').innerHTML = d.waitlist.length
    ? d.waitlist.map(w => `<tr><td>${w.section_id}</td><td>${w.course_code}</td><td>${w.reg_no}</td><td>${w.student_name}</td><td>${w.position}</td></tr>`).join('')
    : `<tr><td colspan="5" class="muted">No one is waitlisted.</td></tr>`;

  // audit
  document.querySelector('#audit tbody').innerHTML = d.audit.length
    ? d.audit.map(a => `<tr><td>${a.audit_id}</td><td>${a.reg_no}</td><td>${a.course_code}</td><td>${a.old_status?badge(a.old_status):'<span class="muted">—</span>'}</td><td>${badge(a.new_status)}</td><td class="muted">${a.changed_by}</td><td class="muted">${a.changed_at}</td></tr>`).join('')
    : `<tr><td colspan="7" class="muted">No changes logged yet.</td></tr>`;

  // faculty
  document.querySelector('#faculty tbody').innerHTML = d.faculty.map(f =>
    `<tr><td>${f.faculty}</td><td>${f.sections}</td><td>${f.courses}</td><td>${f.total_registered}</td></tr>`).join('');

  // dropdowns
  ['r-student','d-student','g-student','t-student'].forEach(id => fillStudents(document.getElementById(id), d.students));
  ['r-section','d-section','g-section'].forEach(id => fillSections(document.getElementById(id), d.sections));
}

async function doAction(kind){
  const map = {
    register:{url:'/api/register', s:'r-student', sec:'r-section'},
    drop:    {url:'/api/drop',     s:'d-student', sec:'d-section'},
    grade:   {url:'/api/grade',    s:'g-student', sec:'g-section'},
  };
  const c = map[kind];
  const body = {student_id: document.getElementById(c.s).value,
                section_id: document.getElementById(c.sec).value};
  if (kind === 'grade') body.grade = document.getElementById('g-grade').value;
  try{
    const r = await (await fetch(c.url, {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(body)})).json();
    r.message.split('\n').forEach(line => line && log(line, r.ok));
  }catch(e){ log('Request failed: ' + e, false); }
  refresh();
}

async function loadTranscript(){
  const sid = document.getElementById('t-student').value;
  const d = await (await fetch('/api/transcript/' + sid)).json();
  const out = document.getElementById('transcript-out');
  if (!d.ok || !d.info){ out.innerHTML = '<p class="muted">No data.</p>'; return; }
  out.innerHTML =
    `<div class="tr-head"><div><b>${d.info.reg_no}</b> — ${d.info.name}</div><div class="cgpa">CGPA ${d.info.cgpa}</div></div>
     <div class="table-wrap"><table><thead><tr><th>Course</th><th>Title</th><th>Cr</th><th>Grade</th><th>Pts</th><th>Term</th><th>Status</th></tr></thead>
     <tbody>${d.rows.map(r=>`<tr><td><b>${r.course_code}</b></td><td>${r.title}</td><td>${r.credits}</td><td>${r.grade||'—'}</td><td>${r.grade_points??'—'}</td><td>${r.term_name}</td><td>${badge(r.status)}</td></tr>`).join('')}</tbody></table></div>`;
}

// demo-shortcut chips prefill the forms
document.addEventListener('click', e => {
  const chip = e.target.closest('.chip');
  if (!chip) return;
  const pane = chip.closest('.tabpane').dataset.pane;
  const pre = pane === 'register' ? 'r' : pane === 'drop' ? 'd' : 'g';
  document.getElementById(pre+'-student').value = chip.dataset.s;
  document.getElementById(pre+'-section').value = chip.dataset.sec;
  if (chip.dataset.g) document.getElementById('g-grade').value = chip.dataset.g;
});

tabGroup('action-tabs');
tabGroup('view-tabs');
document.getElementById('refresh').addEventListener('click', refresh);
refresh();