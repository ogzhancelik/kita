// Firebase Cloud Messaging Background Service Worker for Kita Web
importScripts('https://www.gstatic.com/firebasejs/10.8.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.8.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyDln7rxXDAPEH26e281q_2fGPl_8JZxm8I",
  authDomain: "kita-dev-c2d29.firebaseapp.com",
  projectId: "kita-dev-c2d29",
  storageBucket: "kita-dev-c2d29.firebasestorage.app",
  messagingSenderId: "923836953119",
  appId: "1:923836953119:web:685ffdc5f11e99f441db2a",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notificationTitle = payload.notification?.title || payload.data?.title || 'Kita Online';
  const notificationOptions = {
    body: payload.notification?.body || payload.data?.body || '',
    icon: '/icons/Icon-192.png',
    tag: payload.notification?.tag || payload.data?.tag || 'kita_notification',
    data: payload.data
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const data = event.notification.data || {};

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
      for (let client of windowClients) {
        if ('focus' in client) {
          return client.focus();
        }
      }
      if (clients.openWindow) {
        let targetUrl = '/';
        if (data.type === 'room_joined' && data.room_code) {
          targetUrl = '/#room=' + data.room_code;
        } else if (data.type === 'opponent_moved') {
          targetUrl = '/';
        }
        return clients.openWindow(targetUrl);
      }
    })
  );
});
