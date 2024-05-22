import { initializeApp } from "firebase/app";
// import * as firebase from "firebase";
// Optionally import the services that you want to use
import { initializeAuth } from 'firebase/auth';
import { getDatabase, ref } from "firebase/database";
// import {...} from "firebase/firestore";
// import {...} from "firebase/functions";
import { getStorage } from "firebase/storage";
import { getAnalytics } from "firebase/analytics";
// Initialize Firebase
const firebaseConfig = {
    apiKey: "AIzaSyBVUwTCTvah5wRiiIxDun8YpMfeRYaQPqo",
    authDomain: "amplify-dentistry-9c178.firebaseapp.com",
    projectId: "amplify-dentistry-9c178",
    storageBucket: "amplify-dentistry-9c178.appspot.com",
    messagingSenderId: "1029656965103",
    databaseURL: "https://amplify-dentistry-9c178-default-rtdb.asia-southeast1.firebasedatabase.app/",
    appId: "1:1029656965103:web:eac462a52a6b4c78aa101a",
    measurementId: "G-TYSNZVGY45"
  };
  
// if (!firebase.apps.length) {
//   firebase.initializeApp(firebaseConfig);
// }

const app = initializeApp(firebaseConfig);
// For more information on how to access Firebase in your project,
// see the Firebase documentation: https://firebase.google.com/docs/web/setup#access-firebase

// export { firebase };
// const database = getDatabase(app)
export const db = getDatabase(app)
export const auth = initializeAuth(app);
export const storage = getStorage(app)
//export const analytics = getAnalytics(app);
