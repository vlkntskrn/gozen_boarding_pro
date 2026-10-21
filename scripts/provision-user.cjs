// Trusted workstation only. Uses Application Default Credentials and IAM.
// Usage: node scripts/provision-user.cjs <existing-auth-uid> <Agent|Supervisor|Admin>
// No email-based admin exception; role data is never writable by app clients.
const admin = require('../functions/node_modules/firebase-admin');
admin.initializeApp();
(async () => {
  const [uid, role] = process.argv.slice(2);
  if (!uid || !['Agent', 'Supervisor', 'Admin'].includes(role)) throw Error('Expected uid and valid role');
  const user = await admin.auth().getUser(uid);
  if (!user.email || user.disabled) throw Error('Active email account required');
  await admin.firestore().doc(`users/${uid}`).set({
    email: user.email.toLowerCase(), usernameLower: user.email.split('@')[0].toLowerCase(),
    role, active: true, allowedAirports: role === 'Supervisor' ? ['DLM'] : [],
    provisionedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge:true});
  console.log('Profile provisioned.');
})().catch((e) => { console.error(e.message); process.exitCode = 1; });
