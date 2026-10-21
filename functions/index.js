const {beforeUserCreated, HttpsError} =
  require("firebase-functions/v2/identity");

// Requires Firebase Authentication with Identity Platform.
// Trusted operators provision accounts via Admin SDK, bypassing this hook.
exports.blockClientSignup = beforeUserCreated(() => {
  throw new HttpsError("permission-denied",
      "Accounts are created by authorized administrators only.");
});

const {onCall} = require("firebase-functions/v2/https");
const {defineSecret, defineString} = require("firebase-functions/params");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const nodemailer = require("nodemailer");
const {validateFiles} = require("./closure");
initializeApp();
const smtpPassword = defineSecret("REPORT_SMTP_PASSWORD");
const smtpHost = defineString("REPORT_SMTP_HOST");
const smtpUser = defineString("REPORT_SMTP_USER");
const smtpFrom = defineString("REPORT_SMTP_FROM");

exports.sendFlightClosure = onCall({
  secrets: [smtpPassword], enforceAppCheck: true, timeoutSeconds: 120,
}, async (request) => {
  const uid = request.auth && request.auth.uid;
  const id = request.data && request.data.flightId;
  if (!uid || typeof id !== "string" || !/^[A-Za-z0-9_-]{1,128}$/.test(id)) {
    throw new HttpsError("permission-denied", "Authorization required");
  }
  const db = getFirestore();
  const [profile, snap] = await Promise.all([db.doc(`users/${uid}`).get(), db.doc(`flights/${id}`).get()]);
  const f = snap.data();
  if (!profile.exists || profile.data().active !== true || !f || !f.closed || f.recordingUid !== uid ||
      !(f.participants.includes(uid) || ["Admin", "Supervisor"].includes(profile.data().role))) {
    throw new HttpsError("permission-denied", "Closed recording flight required");
  }
  const recipients = f.reportRecipients;
  if (!Array.isArray(recipients) || !recipients.length || recipients.length > 10 ||
      recipients.some((e) => typeof e !== "string" || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e))) {
    throw new HttpsError("failed-precondition", "Admin must configure recipients");
  }
  let report;
  try {
    report = validateFiles(f, request.data.files);
  } catch (_) {
    throw new HttpsError("invalid-argument", "Invalid report attachments");
  }
  const delivery = db.doc(`reportDeliveries/${id}`);
  const state = await db.runTransaction(async (tx) => {
    const prior = (await tx.get(delivery)).data();
    if (prior) {
      if (prior.hash !== report.hash) throw new HttpsError("failed-precondition", "Reports already finalized");
      if (prior.status === "ACCEPTED") return "ACCEPTED";
      throw new HttpsError("failed-precondition", "Delivery pending or uncertain; operator review required");
    }
    tx.create(delivery, {hash: report.hash, status: "PROCESSING", at: FieldValue.serverTimestamp()});
    return "NEW";
  });
  if (state === "ACCEPTED") return {status: "ACCEPTED"};
  try {
    const transport = nodemailer.createTransport({
      host: smtpHost.value(), port: 465, secure: true,
      auth: {user: smtpUser.value(), pass: smtpPassword.value()},
      connectionTimeout: 15000, socketTimeout: 45000,
    });
    const sent = await transport.sendMail({
      from: smtpFrom.value(), to: recipients,
      subject: `${f.flightCode} ${f.etdDateText} Flight Reports`,
      text: "Passenger search form and daily flight report attached. Handwritten signature fields require completion.",
      attachments: report.attachments,
      messageId: `<gozen-flight-${id}@${smtpFrom.value().split("@").pop()}>`,
    });
    if (sent.rejected && sent.rejected.length) throw new Error("Not all recipients accepted");
    await delivery.update({status: "ACCEPTED", at: FieldValue.serverTimestamp()});
    return {status: "ACCEPTED"};
  } catch (_) {
    // SMTP acknowledgement can be lost. Never resend automatically, which
    // could duplicate an already delivered message. No passenger data logged.
    await delivery.update({status: "NEEDS_REVIEW", at: FieldValue.serverTimestamp()});
    throw new HttpsError("unavailable", "Mail acceptance unconfirmed; operator review required");
  }
});
