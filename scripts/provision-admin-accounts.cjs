// Trusted workstation only. Requires Firebase Admin ADC for volkan-589c1.
// Read [{email,password}] JSON from stdin. Never put passwords in arguments,
// source, CI logs, the APK, or a committed file.
const fs = require('node:fs');
const admin = require('../functions/node_modules/firebase-admin');
async function main() {
  const accounts = JSON.parse(fs.readFileSync(0, 'utf8'));
  if (!Array.isArray(accounts) || accounts.length < 1 || accounts.length > 10) throw new Error('Invalid account list.');
  for (const a of accounts) {
    if (!/^[A-Za-z0-9._%+-]+@gozensecurity\.com$/.test(a.email || '') || typeof a.password !== 'string' || a.password.length < 8) {
      throw new Error('Invalid company email/password.');
    }
  }
  admin.initializeApp({credential: admin.credential.applicationDefault(), projectId: 'volkan-589c1'});
  for (const a of accounts) {
    let user;
    try {user = await admin.auth().getUserByEmail(a.email);}
    catch (e) {if (e.code !== 'auth/user-not-found') throw e;}
    if (user) user = await admin.auth().updateUser(user.uid, {password: a.password, disabled: false});
    else user = await admin.auth().createUser({email: a.email, password: a.password, disabled: false});
    await admin.auth().setCustomUserClaims(user.uid, {...user.customClaims, role: 'Admin'});
    await admin.firestore().collection('users').doc(user.uid).set({email: a.email, role: 'Admin', active: true,
      provisionedAt: admin.firestore.FieldValue.serverTimestamp()}, {merge: true});
    console.log('Admin account provisioned.');
    a.password = '';
  }
}
main().catch(() => {console.error('Provisioning failed; review Auth/Firestore on the trusted admin workstation.'); process.exitCode = 1;});
