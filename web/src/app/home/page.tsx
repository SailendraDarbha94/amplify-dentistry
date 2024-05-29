"use client";
import { useContext, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { getAuth, onAuthStateChanged } from "firebase/auth";
import app from "@/lib/firebase";
import Years from "@/components/Years";

const Page = () => {
  const router = useRouter();

  const [user, setUser] = useState<any>(null);

  useEffect(() => {
    const auth =  getAuth(app)
    onAuthStateChanged(auth, user => {
      if(user){
        setUser(user);
      } else{
        router.push("/");
      }
    })
  },[])
  

  return (
    <main className="min-h-screen">
      <Years />
    </main>
  );
};

export default Page;
