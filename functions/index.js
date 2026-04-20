const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.onOrderStatusChanged = functions.firestore
  .document("orders/{orderId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    if (before.status === after.status) {
      return null;
    }

    // Scaffold only:
    // In production, create notification documents, send FCM messages,
    // and enforce protected transition logic here.
    return admin.firestore().collection("notifications").add({
      userId: after.customerId,
      orderId: context.params.orderId,
      title: "Order update",
      body: `Your order is now ${after.status}.`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      source: "cloud-function-scaffold"
    });
  });
