const admin = require("firebase-admin");
const { onCall, HttpsError } = require("firebase-functions/v2/https");

admin.initializeApp();

function generateRandomPassword(length = 10) {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";
  let password = "";
  for (let i = 0; i < length; i += 1) {
    password += chars[Math.floor(Math.random() * chars.length)];
  }
  return password;
}

exports.adminResetResidentPassword = onCall(async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Harus login terlebih dahulu.");
  }

  const callerUserDoc = await admin
    .firestore()
    .collection("users")
    .doc(request.auth.uid)
    .get();

  const callerRole = (callerUserDoc.data()?.role || "").toString().toLowerCase();
  if (!["admin", "sekretaris"].includes(callerRole)) {
    throw new HttpsError(
      "permission-denied",
      "Hanya admin/sekretaris yang dapat reset password warga.",
    );
  }

  const wargaId = (request.data?.wargaId || "").toString().trim();
  const newPasswordInput = (request.data?.newPassword || "").toString().trim();

  if (!wargaId) {
    throw new HttpsError("invalid-argument", "wargaId wajib diisi.");
  }

  if (newPasswordInput && newPasswordInput.length < 6) {
    throw new HttpsError(
      "invalid-argument",
      "Password minimal 6 karakter.",
    );
  }

  const usersSnap = await admin
    .firestore()
    .collection("users")
    .where("wargaId", "==", wargaId)
    .limit(1)
    .get();

  if (usersSnap.empty) {
    throw new HttpsError("not-found", "Akun warga tidak ditemukan.");
  }

  const userDoc = usersSnap.docs[0];
  const userData = userDoc.data() || {};
  const authUid = (userData.authUid || userDoc.id || "").toString().trim();
  const authEmail = (userData.authEmail || "").toString().trim();

  if (!authUid || !authEmail) {
    throw new HttpsError(
      "failed-precondition",
      "Akun warga belum terhubung penuh ke Firebase Auth.",
    );
  }

  const password = newPasswordInput || generateRandomPassword();

  await admin.auth().updateUser(authUid, { password });
  await userDoc.ref.set(
    {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedByPasswordResetAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedByPasswordResetUid: request.auth.uid,
    },
    { merge: true },
  );

  return {
    wargaId,
    authUid,
    authEmail,
    password,
    generated: !newPasswordInput,
  };
});
