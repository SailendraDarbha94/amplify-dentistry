"use client"
import app from "@/config/firebase";
import { getAuth, onAuthStateChanged } from "firebase/auth";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

export default function HomeLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  //const [user,setUser] = useState<any | null>(null)
  const router = useRouter();

  useEffect(() => {
    const auth = getAuth(app);

    onAuthStateChanged(auth, (user) => {
      if (user) {
        console.log(user);
      } else {
        router.push("/");
      }
    });
  }, []);

  return <main className="p-4 bg-pink-500">{children}</main>;
}
