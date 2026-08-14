// SARGE web push service worker.
// Registers Firebase Messaging in the service worker scope so web clients
// can receive push notifications (background + foreground) via FCM.
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCL6ZM88tMNECP7A2xJWH07SEooEG7wQzo',
  authDomain: 'sargeapp.firebaseapp.com',
  projectId: 'sargeapp',
  storageBucket: 'sargeapp.firebasestorage.app',
  messagingSenderId: '343221111506',
  appId: '1:343221111506:web:b8048af1792b15a19efb0b',
});

const messaging = firebase.messaging();

// Receives background messages when the app is not in the foreground.
// The browser shows a notification automatically for payloads that include
// a `notification` block, so this handler only needs to be present to opt in.
messaging.onBackgroundMessage((payload) => {
  self.registration.showNotification(payload.notification.title, {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png',
  });
});