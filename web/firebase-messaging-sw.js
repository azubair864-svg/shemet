importScripts('https://www.gstatic.com/firebasejs/9.10.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.10.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyB9TKP-TFluGRMV04kTe3L7cijNugc-iRM",
  authDomain: "dating-live-app-477af.firebaseapp.com",
  projectId: "dating-live-app-477af",
  storageBucket: "dating-live-app-477af.firebasestorage.app",
  messagingSenderId: "351905956852",
  appId: "1:351905956852:web:9835da2a1db9a4945a2fa1"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/favicon.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
