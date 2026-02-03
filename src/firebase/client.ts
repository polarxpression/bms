import { initializeApp } from "firebase/app";
import { getAuth } from "firebase/auth";
import { getFirestore } from "firebase/firestore";
import { getStorage } from "firebase/storage";

const firebaseConfig = {
  apiKey: "AIzaSyBMKc42PJ5_Iztm6zruI3QND6uv2t5ZaEg",
  authDomain: "batterybuddy-3fe86.firebaseapp.com",
  projectId: "batterybuddy-3fe86",
  storageBucket: "batterybuddy-3fe86.firebasestorage.app",
  messagingSenderId: "577036011593",
  appId: "1:577036011593:web:4afab6b249ead3923e1798",
  measurementId: "G-EQJW5BPCW9"
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);
export const storage = getStorage(app);