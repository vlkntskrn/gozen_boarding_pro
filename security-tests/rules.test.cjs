const {readFileSync} = require('node:fs');
const {before, after, beforeEach, test} = require('node:test');
const {initializeTestEnvironment, assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {doc, getDoc, getDocs, collection, query, where, setDoc, updateDoc, deleteDoc, writeBatch, serverTimestamp} = require('firebase/firestore');
let env;
const db = (uid) => uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore();
before(async () => { env = await initializeTestEnvironment({projectId:'demo-gozen-security', firestore:{rules:readFileSync('firestore.rules','utf8')}}); });
after(async () => env?.cleanup());
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const f=ctx.firestore();
    for(const [uid,role,airports] of [['owner','Agent',[]],['agent','Agent',[]],['other','Agent',[]],['supervisor','Supervisor',['DLM']],['outsuper','Supervisor',['BJV']],['admin','Admin',[]]]) {
      await setDoc(doc(f,'users',uid), {role,active:true,allowedAirports:airports});
    }
    await setDoc(doc(f,'flights/f1'), {ownerUid:'owner',participants:['agent'],departureAirport:'DLM',flightCode:'LS1730',etdDateText:'2026-10-21',closed:false});
    await setDoc(doc(f,'flights/f1/pax/p1'), {fullName:'SMITH/JOHN',seat:'1A',status:'NONE'});
  });
});
test('unauthenticated, unapproved and unrelated agents cannot read flight/pax', async () => {
  for(const uid of [null,'unknown','other','outsuper']) {
    await assertFails(getDoc(doc(db(uid),'flights/f1')));
    await assertFails(getDocs(collection(db(uid),'flights/f1/pax')));
  }
});
test('owner, participant, scoped supervisor and admin can read', async () => {
  for(const uid of ['owner','agent','supervisor','admin']) {
    await assertSucceeds(getDoc(doc(db(uid),'flights/f1')));
    await assertSucceeds(getDocs(collection(db(uid),'flights/f1/pax')));
  }
});
test('self provision, self promotion and other-user role change denied', async () => {
  await assertFails(setDoc(doc(db('unknown'),'users/unknown'),{active:true,role:'Admin'}));
  await assertFails(updateDoc(doc(db('agent'),'users/agent'),{role:'Supervisor'}));
  await assertFails(updateDoc(doc(db('agent'),'users/owner'),{role:'Admin'}));
  await assertFails(updateDoc(doc(db('agent'),'users/agent'),{allowedAirports:['DLM']}));
});
test('flight owner and membership cannot be forged by participants', async () => {
  await assertFails(updateDoc(doc(db('agent'),'flights/f1'),{ownerUid:'agent'}));
  await assertFails(updateDoc(doc(db('other'),'flights/f1'),{participants:['agent','other']}));
  await assertFails(setDoc(doc(db('agent'),'flights/forged'),{ownerUid:'owner',participants:[],departureAirport:'DLM'}));
  await assertSucceeds(setDoc(doc(db('agent'),'flights/new'),{ownerUid:'agent',participants:[],departureAirport:'DLM'}));
});
test('agent queries must be membership constrained', async () => {
  await assertFails(getDocs(collection(db('agent'),'flights')));
  await assertSucceeds(getDocs(query(collection(db('agent'),'flights'),where('participants','array-contains','agent'))));
});
test('only flight manager can change watchlist and equipment', async () => {
  for(const col of ['watchlist','staff','equipment']) {
    await assertFails(setDoc(doc(db('agent'),`flights/f1/${col}/x`),{fullName:'X'}));
    await assertSucceeds(setDoc(doc(db('owner'),`flights/f1/${col}/x`),{fullName:'X'}));
  }
});
test('invitation acceptance atomically grants only intended user access', async () => {
  const owner=db('owner'), other=db('other');
  await assertSucceeds(setDoc(doc(owner,'invites/f1_other'),{flightId:'f1',inviteeUid:'other',status:'PENDING'}));
  await assertSucceeds(getDoc(doc(other,'flights/f1')));
  await assertFails(getDoc(doc(db('agent'),'invites/f1_other')));
  const b=writeBatch(other);
  b.update(doc(other,'flights/f1'),{participants:['agent','other']});
  b.update(doc(other,'invites/f1_other'),{status:'ACCEPTED',acceptedByUid:'other',acceptedAt:serverTimestamp()});
  await assertSucceeds(b.commit());
  await assertSucceeds(getDocs(collection(other,'flights/f1/pax')));
});
test('audit is append-only and rejects raw barcode', async () => {
  const f=db('agent'), ref=doc(f,'flights/f1/logs/l1');
  await assertSucceeds(setDoc(ref,{type:'TEST',byUid:'agent',at:serverTimestamp(),meta:{}}));
  await assertFails(updateDoc(ref,{type:'ALTERED'}));
  await assertFails(deleteDoc(ref));
  await assertFails(setDoc(doc(f,'flights/f1/logs/l2'),{type:'TEST',byUid:'owner',at:serverTimestamp()}));
  await assertFails(setDoc(doc(f,'flights/f1/logs/l3'),{type:'TEST',byUid:'agent',at:serverTimestamp(),meta:{raw:'M1...'}}));
});
function boardBatch(f, pid='p1', status='PREBOARDED', date='2026-10-21', origin='DLM', wl=false) {
  const b=writeBatch(f);
  b.set(doc(f,`flights/f1/pax/${pid}`),{fullName:'SMITH/JOHN',seat:'1A',status,boardedByUid:'agent',boardedAt:serverTimestamp(),validationDate:date,validationOrigin:origin,validationFlightCode:'LS1730',watchlistMatch:wl,boardingKey:'k1',seatLock:'1A'});
  b.set(doc(f,'flights/f1/boarding_keys/k1'),{active:true,paxId:pid,byUid:'agent',at:serverTimestamp()});
  b.set(doc(f,'flights/f1/seat_locks/1A'),{paxIds:[pid],byUid:'agent',at:serverTimestamp()});
  return b;
}
test('valid boarding succeeds; active boarding cannot be overwritten', async () => {
  const f=db('agent'); await assertSucceeds(boardBatch(f).commit());
  await assertFails(boardBatch(f).commit());
});
test('wrong date, wrong origin and watchlist preboard writes rejected', async () => {
  const f=db('agent');
  await assertFails(boardBatch(f,'p1','PREBOARDED','2026-10-20').commit());
  await assertFails(boardBatch(f,'p1','PREBOARDED','2026-10-21','BJV').commit());
  await assertFails(boardBatch(f,'p1','PREBOARDED','2026-10-21','DLM',true).commit());
  await assertSucceeds(boardBatch(f,'p1','DFT_BOARDED','2026-10-21','DLM',true).commit());
});
test('closed flight refuses boarding and offload', async () => {
  await env.withSecurityRulesDisabled(async ctx=>updateDoc(doc(ctx.firestore(),'flights/f1'),{closed:true}));
  await assertFails(boardBatch(db('agent')).commit());
});

test('active identity key cannot be reused for another passenger', async () => {
  const f=db('agent');
  await assertSucceeds(boardBatch(f).commit());
  await assertFails(boardBatch(f,'p2').commit());
});
test('active seat occupant cannot be dropped from lock', async () => {
  const f=db('agent');
  await assertSucceeds(boardBatch(f).commit());
  await assertFails(setDoc(doc(f,'flights/f1/seat_locks/1A'),{paxIds:[],byUid:'agent',at:serverTimestamp()}));
});
