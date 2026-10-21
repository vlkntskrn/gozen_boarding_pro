const {beforeUserCreated, HttpsError} =
  require("firebase-functions/v2/identity");

// Requires Firebase Authentication with Identity Platform.
// Trusted operators provision accounts via Admin SDK, bypassing this hook.
exports.blockClientSignup = beforeUserCreated(() => {
  throw new HttpsError("permission-denied",
      "Accounts are created by authorized administrators only.");
});
