// Import the functions you need from the SDKs you need
import { initializeApp } from "firebase/app";
import { getAnalytics } from "firebase/analytics";
// TODO: Add SDKs for Firebase products that you want to use
// https://firebase.google.com/docs/web/setup#available-libraries

// Your web app's Firebase configuration
// For Firebase JS SDK v7.20.0 and later, measurementId is optional
const firebaseConfig = {
  apiKey: "AIzaSyBv0ByyAMx3IVk9XFIUOvwqi4DDHz1_n6M",
  authDomain: "amplify-dentistry.firebaseapp.com",
  projectId: "amplify-dentistry",
  storageBucket: "amplify-dentistry.appspot.com",
  messagingSenderId: "610401028838",
  appId: "1:610401028838:web:d76b691e8e82d52e4a0927",
  measurementId: "G-S34D0N1QYZ"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const analytics = getAnalytics(app);