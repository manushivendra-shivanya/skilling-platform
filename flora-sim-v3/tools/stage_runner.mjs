/* Headless reference runner for Flora stage contracts.
   Loads a stage JSON + a scenario + a scripted learner run, emits an append-only
   LearnerAction stream, and computes COMPLETION and (separately) CORRECTNESS +
   competency evidence. No Flutter, no 3D — this is the fast unit-test loop, and a
   reference the backend mirrors. Run: node stage_runner.mjs */
import fs from 'fs';
import path from 'path';
const dir = path.dirname(new URL(import.meta.url).pathname);
const load = f => JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8'));

let SEQ = 0;
const emit = (stream, action, extra = {}) => {
  const rec = { seq: ++SEQ, ts: 1000 + SEQ, action, ...extra };
  stream.push(rec);
  return rec;
};
const tallyComp = (stream, catalogByAction) => {
  const t = {};
  for (const a of stream) {
    const comps = catalogByAction[a.action] || a.competencies || [];
    for (const c of comps) t[c] = (t[c] || 0) + 1;
  }
  return t;
};
const bar = (v) => '█'.repeat(Math.round(v * 20)).padEnd(20, '·');
const pct = (v) => (Math.round(v * 100) + '%').padStart(4);

/* ---------- Verification stage (Screen 06) ---------- */
function runVerification(stage, scenarioId, script, label) {
  SEQ = 0;
  const scenario = stage.scenarios.find(s => s.id === scenarioId);
  const stream = [];
  const catalog = Object.fromEntries((stage.learnerActionsCatalog || []).map(a => [a.action, a.competencies]));
  const verified = new Set();
  const viaIndex = {}; // action -> checklist ids it can verify
  for (const c of stage.verificationChecklist) for (const v of c.via) (viaIndex[v] ||= []).push(c.id);

  let terminal = null, terminalSeq = null;
  for (const step of script) {
    const rec = emit(stream, step.action, { target: step.target, competencies: catalog[step.action] });
    (viaIndex[step.action] || []).forEach(id => verified.add(id));
    const cat = stage.completion.terminalMap[step.action];
    if (cat && !terminal) { terminal = cat; terminalSeq = rec.seq; }
  }

  const completion = !!terminal && stage.completion.validOutcomes.includes(terminal);
  const outcomeCorrect = terminal === scenario.expectedOutcome;
  const critical = scenario.criticalChecks || [];
  const dueDone = critical.filter(c => verified.has(c)).length;
  const dueDiligence = critical.length ? dueDone / critical.length : 1;
  const correctness = (outcomeCorrect ? 0.6 : 0) + 0.4 * dueDiligence;

  report(label, stage, scenario, {
    completion,
    lines: [
      ['outcome', `${terminal || '—'}  (expected ${scenario.expectedOutcome})  ${outcomeCorrect ? 'MATCH' : 'MISMATCH'}`],
      ['due-diligence', `${dueDone}/${critical.length} critical checks done before deciding`],
    ],
    correctness, stream, comp: tallyComp(stream, catalog),
  });
  return { completion, correctness };
}

/* ---------- Inspection stage (Screen 07) ---------- */
function runInspection(stage, scenarioId, run, label) {
  SEQ = 0;
  const scenario = stage.scenarios.find(s => s.id === scenarioId);
  const gt = scenario.config.groundTruth || [];
  const stream = [];
  const catalog = Object.fromEntries((stage.learnerActionsCatalog || []).map(a => [a.action, a.competencies]));

  // scripted actions -> evidence
  for (const a of run.actions) emit(stream, a.action, { target: a.target, competencies: catalog[a.action] });
  // recorded findings emit recorded_damage evidence
  for (const f of run.recorded) emit(stream, 'recorded_damage', { target: f.item, meta: f, competencies: catalog['recorded_damage'] });
  if (run.submitted) emit(stream, 'submitted_report');

  // match recorded vs ground truth by (item,type)
  const key = f => f.item + '|' + f.type;
  const gtMap = new Map(gt.map(f => [key(f), f]));
  const matched = [], falsePos = [];
  for (const f of run.recorded) { const g = gtMap.get(key(f)); if (g) matched.push([f, g]); else falsePos.push(f); }
  const missed = gt.filter(g => !run.recorded.some(f => key(f) === key(g)));

  const recall = gt.length ? matched.length / gt.length : (run.recorded.length === 0 ? 1 : 0);
  const precision = run.recorded.length ? matched.length / run.recorded.length : (gt.length === 0 ? 1 : 0);
  const sevAcc = matched.length ? matched.filter(([f, g]) => f.severity === g.severity).length / matched.length : 1;
  const qAcc = matched.length ? matched.filter(([f, g]) => f.action === g.action).length / matched.length : 1;
  const completeness = run.palletsInspected / run.palletsAssigned;

  const completion = run.submitted && run.palletsInspected >= run.palletsAssigned;
  const correctness = recall * 0.4 + precision * 0.3 + sevAcc * 0.15 + qAcc * 0.15;

  report(label, stage, scenario, {
    completion,
    lines: [
      ['completeness', `${run.palletsInspected}/${run.palletsAssigned} pallets inspected`],
      ['defects', `${matched.length}/${gt.length} found · ${missed.length} missed · ${falsePos.length} false-positive`],
      ['recall', pct(recall) + ' ' + bar(recall)],
      ['precision', pct(precision) + ' ' + bar(precision)],
      ['severity acc', pct(sevAcc)],
      ['quarantine acc', pct(qAcc)],
    ],
    correctness, stream, comp: tallyComp(stream, catalog),
    extra: missed.length ? '   ⚠ missed: ' + missed.map(m => m.item + '/' + m.type).join(', ') : '',
  });
  return { completion, correctness };
}

/* ---------- pretty report ---------- */
function report(label, stage, scenario, r) {
  console.log('\n' + '─'.repeat(64));
  console.log(`▶ ${stage.meta.title}  ·  Scenario ${scenario.id} — ${scenario.name}`);
  console.log(`  ${label}`);
  console.log('  COMPLETION : ' + (r.completion ? '✓ complete' : '✗ incomplete') + '   (workflow reached a terminal/submitted state)');
  console.log('  CORRECTNESS: ' + pct(r.correctness) + '  ' + bar(r.correctness) + '   (assessed separately)');
  for (const [k, v] of r.lines) console.log('     · ' + k.padEnd(15) + v);
  if (r.extra) console.log(r.extra);
  const comps = Object.entries(r.comp).map(([k, n]) => `${k}×${n}`).join('  ');
  console.log('  competency evidence: ' + (comps || '—'));
  console.log('  LearnerAction stream (append-only): ' + r.stream.length + ' events, seq 1..' + r.stream.length);
}

/* ============================ demo runs ============================ */
console.log('Flora stage runner — headless reference. Completion and correctness are separate.');

const s06 = load('screen06.receiving-dock.json');
// Scenario B = vehicle registration mismatch (expected: escalate)
runVerification(s06, 'B',
  [ { action: 'view_vehicle_number', target: 'delivery_truck' },
    { action: 'compare_po_delivery' },
    { action: 'check_seal' },
    { action: 'reported_discrepancy' } ],
  'Diligent learner: checked vehicle + docs + seal, then escalated.');
runVerification(s06, 'B',
  [ { action: 'speak_driver' },
    { action: 'approved_unloading' } ],
  'Sloppy learner: chatted, approved without checking the vehicle.');

const s07 = load('screen07.goods-inspection.json');
// Scenario C = broken pallet + 3 crushed cartons (2 ground-truth defects)
runInspection(s07, 'C', {
  palletsAssigned: 3, palletsInspected: 3, submitted: true,
  actions: [{ action: 'selected_pallet' }, { action: 'zoomed_inspection' }, { action: 'opened_carton' }, { action: 'completed_pallet_inspection' }],
  recorded: [
    { item: 'P2', type: 'broken_pallet', severity: 'major', action: 'quarantine' },
    { item: 'P2-C01', type: 'crushed_carton', severity: 'major', action: 'quarantine' },
  ],
}, 'Thorough inspector: all pallets, both defects, correct severity + action.');
runInspection(s07, 'C', {
  palletsAssigned: 3, palletsInspected: 2, submitted: true,
  actions: [{ action: 'selected_pallet' }, { action: 'completed_pallet_inspection' }],
  recorded: [
    { item: 'P2', type: 'broken_pallet', severity: 'minor', action: 'accept' },
    { item: 'P1-C09', type: 'wet_carton', severity: 'minor', action: 'quarantine' },
  ],
}, 'Rushed inspector: skipped a pallet, wrong severity, missed a defect, one false positive.');

console.log('\n' + '─'.repeat(64));
console.log('Note: both "sloppy" runs COMPLETE the stage but score low CORRECTNESS — exactly Flora\'s model.');
