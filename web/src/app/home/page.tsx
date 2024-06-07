// "use client";
// import { useContext, useEffect, useState } from "react";
// import { useRouter } from "next/navigation";
// import { getAuth, onAuthStateChanged } from "firebase/auth";
// import app from "@/lib/firebase";
import Years from "@/components/Years";
import { cookies } from "next/headers";
// import { ToastContext } from "@/providers/ToastContextProvider";

const Page = () => {
  // const router = useRouter();

  // const [user, setUser] = useState<any>(null);
  // const { toast } = useContext(ToastContext);
  // useEffect(() => {
  //   const auth = getAuth(app);
  //   onAuthStateChanged(auth, (user) => {
  //     if (user) {
  //       setUser(user);
  //       toast({ message: "Welcome to AmpDent", type: "greet" })
  //     }
  //   });
  // }, []);

  const cookieStore = cookies();
  const userId = cookieStore.get('user');
  //const email = cookieStore.get('email');

  console.log(userId);

  return (
    <main className="min-h-screen z-0">
      <Years />
    </main>
  );
};

export default Page;
