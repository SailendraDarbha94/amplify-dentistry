"use client";
import { getDatabase, ref, set } from "firebase/database";

import { title } from "@/components/primitives";
import app from "@/config/firebase";
import Form from "./Form";
import { useContext } from "react";
import { ToastContext } from "../providers";
import { useRouter } from "next/navigation";

export default function AuthPage() {
  const router = useRouter();
  const { toast } = useContext(ToastContext);
  const db = getDatabase(app);
  const saveUserData = async (userId: string, name: string, email: string) => {
    try {
      set(ref(db, "users/" + userId), {
        name: name,
        email: email,
        role: "user",
      });
      toast({
        message: "Account Created! Proceed to Login!",
        type: "error",
      });
      router.push("/");
    } catch (err) {
      console.log(JSON.stringify(err));
      toast({
        message: "An Error Occurred! Please try again later",
        type: "error",
      });
    }
  };

  return (
    <div>
      {/* <h1 className={`${title()} hidden md:block`}>Sign Up</h1> */}
      <section className="font-medium md:p-4">
        <div className="flex flex-col items-center justify-center px-6 py-8 mx-auto md:min-h-screen lg:py-0">
          <a
            className="flex items-center mb-6 text-2xl font-semibold text-gray-900 dark:text-white"
            href="/"
          >
            <img
              alt="logo"
              className="w-8 h-8 mr-2"
              src="/images/logo-image.png"
            />
            AmpDent
          </a>
          <div className="w-full bg-white rounded-lg shadow dark:border md:mt-0 sm:max-w-md xl:p-0 dark:bg-gray-800 dark:border-gray-700">
            <div className="p-4 md:p-4 space-y-4 md:space-y-6 sm:p-8">
              <Form saveUserData={saveUserData} />
            </div>
          </div>
        </div>
      </section>
    </div>
  );
}
