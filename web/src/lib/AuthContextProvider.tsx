"use client"
import React, { createContext, useEffect } from "react";
import { useState } from "react";
import { onAuthStateChanged } from "firebase/auth";
import { auth } from "./firebase";

export const AuthContext = createContext<any>({});

const AuthContextProvider = ({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) => {
  const [user, setUser] = useState<any | null>(null);

  useEffect(() => {
    const subscribe = onAuthStateChanged(auth, (user) => {
      if (user) {
        setUser(user);
      } else {
        setUser(null);
      }
    });

    return () => subscribe();
  }, []);

  return (
    <AuthContext.Provider value={{ user }}>
        {children}
    </AuthContext.Provider>
  );
};

export default AuthContextProvider