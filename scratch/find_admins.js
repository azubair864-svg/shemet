const admin = require('firebase-admin');
const serviceAccount = require('./agency-dashboard/serviceAccountKey.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function findAdmins() {
    console.log("Searching for admins...");
    const snapshot = await db.collection('users').where('isAdmin', '==', true).get();
    
    if (snapshot.empty) {
        console.log("No admins found in Firestore.");
        return;
    }

    snapshot.forEach(doc => {
        const data = doc.data();
        console.log(`Admin Found: Email: ${data.email}, Name: ${data.name}, AgencyId: ${data.agencyId}`);
    });
}

findAdmins();
