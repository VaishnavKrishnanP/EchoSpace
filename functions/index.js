const { onSchedule } = require("firebase-functions/v2/scheduler");
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");
const crypto = require("crypto");

// Initialize Firebase Admin SDK
admin.initializeApp();
const db = admin.firestore();

// Configure email transporter
const transporter = nodemailer.createTransport({
  service: functions.config().email.service || "gmail",
  auth: {
    user: functions.config().email.address,
    pass: functions.config().email.password,
  },
});

// Scheduled function to run every 5 minutes
exports.deleteExpiredSpaces = onSchedule(
    { schedule: "every 5 minutes", timeZone: "UTC" },
    async (event) => {
      const now = admin.firestore.Timestamp.now();

      try {
        const expiredSpaces = await db.collection("Spaces")
            .where("expiresAt", "<", now)
            .get();

        if (expiredSpaces.empty) {
          console.log("No expired spaces found.");
          return;
        }

        const batch = db.batch();
        for (const spaceDoc of expiredSpaces.docs) {
          const spaceData = spaceDoc.data();

          if (spaceData.createdBy) {
            const userRef = db.collection("Users").doc(spaceData.createdBy);
            const userDoc = await userRef.get();

            if (userDoc.exists) {
              batch.update(userRef, { hasSpace: false });
            } else {
              console.warn(`User document not found: ${spaceData.createdBy}`);
            }
          }

          batch.delete(spaceDoc.ref);
        }

        await batch.commit();
        console.log(`Deleted ${expiredSpaces.size} expired spaces.`);
      } catch (error) {
        console.error("Error deleting expired spaces:", error);
      }
    }
);

// OTP Generation Function
exports.generateOTP = functions.https.onCall(async (data, context) => {
  if (!data.email) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Email is required"
    );
  }

  const email = data.email.toLowerCase().trim();
  const otp = crypto.randomInt(100000, 999999).toString();
  const expiresAt = Date.now() + 300000; // 5 minutes

  try {
    // Store OTP in Firestore
    await db.collection("otps").doc(email).set({
      otp,
      expiresAt,
      attempts: 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Send email
    const mailOptions = {
      from: `"EchoSpace" <${functions.config().email.address}>`,
      to: email,
      subject: "Your EchoSpace Verification Code",
      text: `Your OTP code is: ${otp}\nThis code expires in 5 minutes.`,
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <h2 style="color: #4f46e5;">EchoSpace Verification</h2>
          <p>Your verification code is:</p>
          <h1 style="font-size: 2.5rem; letter-spacing: 0.5rem; color: #4f46e5;">
            ${otp}
          </h1>
          <p>This code will expire in 5 minutes.</p>
          <p style="color: #6b7280; font-size: 0.875rem;">
            If you didn't request this code, you can safely ignore this email.
          </p>
        </div>
      `,
    };

    await transporter.sendMail(mailOptions);
    return { success: true };
  } catch (error) {
    console.error("OTP generation error:", error);
    throw new functions.https.HttpsError(
      "internal",
      "Failed to generate OTP"
    );
  }
});

// OTP Verification Function
exports.verifyOTP = functions.https.onCall(async (data, context) => {
  if (!data.email || !data.otp) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Email and OTP are required"
    );
  }

  const email = data.email.toLowerCase().trim();
  const otp = data.otp.trim();

  try {
    const otpDoc = await db.collection("otps").doc(email).get();

    if (!otpDoc.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        "OTP not found. Please request a new one."
      );
    }

    const otpData = otpDoc.data();

    // Check if OTP is expired
    if (otpData.expiresAt < Date.now()) {
      await db.collection("otps").doc(email).delete();
      throw new functions.https.HttpsError(
        "deadline-exceeded",
        "OTP expired. Please request a new one."
      );
    }

    // Check if OTP matches
    if (otpData.otp !== otp) {
      const attempts = (otpData.attempts || 0) + 1;

      if (attempts >= 5) {
        await db.collection("otps").doc(email).delete();
        throw new functions.https.HttpsError(
          "permission-denied",
          "Too many failed attempts. Please request a new OTP."
        );
      }

      await db.collection("otps").doc(email).update({ attempts });
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Invalid OTP code"
      );
    }

    // OTP is valid - mark as verified
    await db.collection("otps").doc(email).update({
      verified: true,
      verifiedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    return { success: true, email: email };
  } catch (error) {
    console.error("OTP verification error:", error);
    throw error;
  }
});

