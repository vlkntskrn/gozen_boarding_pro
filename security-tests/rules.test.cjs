const {readFileSync}=require('node:fs');
const {before,after,beforeEach,test}=require('node:test');
const {initializeTestEnvironment,assertFails,assertSucceeds}=require('@firebase/rules-unit-testing');
const {doc,getDoc,getDocs,collection,query,where,setDoc,updateDoc,deleteDoc,serverTimestamp}=require('firebase/firestore');
let env;
const db=uid=>uid?env.authenticatedContext(uid).firestore():env.unauthenticatedContext().firestore();
const flight=()=>({flightCode:'LS196',departureAirport:'DLM',arrivalAirport:'GLA',etdDateText:'2026-10-20',
 bookedPax:191,ownerUid:'admin',participants:['agent','agent2'],reportRecipients:['ops@example.test'],createdAt:serverTimestamp(),closed:false});
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-gozen-security',firestore:{rules:readFileSync('firestore.rules','utf8')}})});
after(async()=>env?.cleanup());
beforeEach(async()=>{
 await env.clearFirestore();
 await env.withSecurityRulesDisabled(async ctx=>{
  const f=ctx.firestore();
  for(const [uid,role] of [['admin','Admin'],['spv','Supervisor'],['agent','Agent'],['agent2','Agent'],['other','Agent']])
   await setDoc(doc(f,'users',uid),{role,active:true});
  await setDoc(doc(f,'flights/f1'),flight());
 });
});
test('assigned people, every SPV and admin read; unrelated users denied',async()=>{
 for(const uid of ['admin','spv','agent','agent2']) await assertSucceeds(getDoc(doc(db(uid),'flights/f1')));
 for(const uid of [null,'unknown','other']) await assertFails(getDoc(doc(db(uid),'flights/f1')));
});
test('only admin creates and assigns flights',async()=>{
 for(const uid of ['agent','spv']) {
  await assertFails(setDoc(doc(db(uid),'flights/new'),{...flight(),ownerUid:uid}));
  await assertFails(updateDoc(doc(db(uid),'flights/f1'),{participants:['other']}));
 }
 await assertSucceeds(setDoc(doc(db('admin'),'flights/new'),flight()));
 await assertSucceeds(updateDoc(doc(db('admin'),'flights/f1'),{participants:['other']}));
 await assertSucceeds(getDoc(doc(db('other'),'flights/f1')));
 await assertFails(getDoc(doc(db('agent'),'flights/f1')));
});
test('clients cannot activate or promote themselves',async()=>{
 for(const uid of ['admin','spv','agent']) await assertFails(updateDoc(doc(db(uid),'users/agent'),{role:'Supervisor'}));
 await assertFails(setDoc(doc(db('unknown'),'users/unknown'),{active:true,role:'Admin'}));
});
test('agent list constrained; SPV lists all flights',async()=>{
 await assertFails(getDocs(collection(db('agent'),'flights')));
 await assertSucceeds(getDocs(query(collection(db('agent'),'flights'),where('participants','array-contains','agent'))));
 await assertSucceeds(getDocs(collection(db('spv'),'flights')));
});
test('no passenger LP watchlist keys or PII logs online even for admin',async()=>{
 for(const uid of ['admin','spv','agent']) for(const col of ['pax','lp','watchlist','boarding_keys','seat_locks']) {
  await assertFails(setDoc(doc(db(uid),`flights/f1/${col}/x`),{name:'PRIVATE'}));
  await assertFails(getDocs(collection(db(uid),`flights/f1/${col}`)));
 }
 await assertFails(updateDoc(doc(db('admin'),'flights/f1'),{pax:[{name:'PRIVATE'}]}));
 await assertFails(setDoc(doc(db('admin'),'flights/new'),{...flight(),rawBarcode:'M1...'}));
 await assertFails(setDoc(doc(db('agent'),'flights/f1/logs/x'),{type:'PAX_BOARDED',byUid:'agent',at:serverTimestamp(),meta:{name:'PRIVATE'}}));
});
test('single recording device is immutable; only recorder closes',async()=>{
 await assertSucceeds(updateDoc(doc(db('agent'),'flights/f1'),{recordingDeviceHash:'a'.repeat(64),recordingUid:'agent'}));
 await assertFails(updateDoc(doc(db('agent2'),'flights/f1'),{recordingDeviceHash:'b'.repeat(64),recordingUid:'agent2'}));
 await assertFails(updateDoc(doc(db('admin'),'flights/f1'),{recordingDeviceHash:'b'.repeat(64)}));
 await assertFails(updateDoc(doc(db('agent2'),'flights/f1'),{closed:true,closedAt:serverTimestamp()}));
 await assertSucceeds(updateDoc(doc(db('agent'),'flights/f1'),{closed:true,closedAt:serverTimestamp()}));
 await assertFails(updateDoc(doc(db('agent'),'flights/f1'),{closed:false}));
});
test('metadata audit append only; no passenger fields allowed',async()=>{
 const ref=doc(db('admin'),'flights/f1/logs/a');
 await assertSucceeds(setDoc(ref,{type:'ASSIGNMENT_CHANGED',byUid:'admin',at:serverTimestamp()}));
 await assertFails(updateDoc(ref,{type:'FLIGHT_CLOSED'}));await assertFails(deleteDoc(ref));
 await assertFails(setDoc(doc(db('agent'),'flights/f1/logs/b'),{type:'FLIGHT_CLOSED',byUid:'admin',at:serverTimestamp()}));
});
