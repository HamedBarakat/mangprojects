importScripts('https://www.gstatic.com/firebasejs/10.0.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.0.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCT_DzOXrc13yux8rV_p0kfcjEdlFogPsw',
  authDomain: 'mangprojects.firebaseapp.com',
  projectId: 'mangprojects',
  storageBucket: 'mangprojects.firebasestorage.app',
  messagingSenderId: '569805089105',
  appId: '1:569805089105:web:3ccb0c53ec3d7e41020b70',
});

const messaging = firebase.messaging();

// Handle background/terminated-tab notifications
messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title ?? 'Mang Projects';
  const options = {
    body: payload.notification?.body ?? '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data ?? {},
  };
  return self.registration.showNotification(title, options);
});
