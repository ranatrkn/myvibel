/*
  remove_robot_field.js

  Safe migration script to remove `robot` field from all documents in `users` collection.
  Usage:
    1) Place your Firebase service account JSON at the repo root as `serviceAccountKey.json`, OR set
       FIREBASE_SERVICE_ACCOUNT env var to the JSON content.
    2) npm install firebase-admin
    3) node scripts/remove_robot_field.js

  The script reads users in batches and issues update({ robot: FieldValue.delete() }) per doc.
  Review and test on a staging project before running in production.
*/

const admin = require('firebase-admin');
const fs = require('fs');

function initFirebase() {
  const keyPath = './serviceAccountKey.json';
  if (fs.existsSync(keyPath)) {
    const serviceAccount = require(keyPath);
    admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
    console.log('Initialized Firebase using serviceAccountKey.json');
    return;
  }

  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    const obj = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    admin.initializeApp({ credential: admin.credential.cert(obj) });
    console.log('Initialized Firebase using FIREBASE_SERVICE_ACCOUNT env var');
    return;
  }

  console.error('No service account provided. Place serviceAccountKey.json in repo root or set FIREBASE_SERVICE_ACCOUNT.');
  process.exit(1);
}

async function run() {
  initFirebase();
  const db = admin.firestore();
  const batchSize = 500;

  console.log('Listing users...');
  const snapshot = await db.collection('users').get();
  console.log(`Found ${snapshot.size} user docs.`);

  let batch = db.batch();
  let ops = 0;
  for (const doc of snapshot.docs) {
    const ref = doc.ref;
    batch.update(ref, { robot: admin.firestore.FieldValue.delete() });
    ops++;
    if (ops >= batchSize) {
      await batch.commit();
      console.log(`Committed ${ops} updates...`);
      batch = db.batch();
      ops = 0;
    }
  }
  if (ops > 0) {
    await batch.commit();
    console.log(`Committed final ${ops} updates.`);
  }

  console.log('Done. The `robot` field has been removed from user documents (where present).');
  process.exit(0);
}

run().catch((err) => {
  console.error('Migration failed:', err);
  process.exit(1);
});
