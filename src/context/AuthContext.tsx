"use client";
import { onAuthStateChanged, getAuth, GoogleAuthProvider, signInWithRedirect } from "firebase/auth";
import firebase_app from "@/firebase/config";
import { createContext, useContext, useEffect, useState } from "react";
import { Button } from "@nextui-org/react";

const auth = getAuth(firebase_app);

export const AuthContext = createContext({});

export const useAuthContext = () => useContext(AuthContext);

export const AuthContextProvider = ({ children }: any) => {
  const [user, setUser] = useState<any>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (user) => {
      if (user) {
        setUser(user);
      } else {
        setUser(null);
      }
      setLoading(false);
    });

    return () => unsubscribe();
  }, []);
  const auth = getAuth(firebase_app);
  const provider = new GoogleAuthProvider();

  const authenticator = () => {
    signInWithRedirect(auth, provider);
    auth.setPersistence
  };
  return (
    <AuthContext.Provider value={{ user }}>
      {loading ? <div>Loading...</div> : children}
    </AuthContext.Provider>
  );
};
