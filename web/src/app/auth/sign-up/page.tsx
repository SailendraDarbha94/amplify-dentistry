"use client";

import { getDatabase, ref, set } from "firebase/database";
import app from "@/lib/firebase";
import Form from "./Form";
const Page = () => {
  const db = getDatabase(app);
  const saveUserData = async (userId: string, name: string, email: string) => {
    try {
      set(ref(db, "users/" + userId), {
        name: name,
        email: email,
        role: "user",
      });
    } catch (err) {
      console.log(JSON.stringify(err));
    }
  };
  return (
    <main>
      <section className="bg-gray-50 dark:bg-gray-900 font-pMedium p-4 md:p-14">
        <div className="flex flex-col items-center justify-center px-6 py-8 mx-auto md:min-h-screen lg:py-0">
          <a
            href="#"
            className="flex items-center mb-6 text-2xl font-semibold text-gray-900 dark:text-white"
          >
            <img className="w-8 h-8 mr-2" src="/logo-image.png" alt="logo" />
            AmpDent
          </a>
          <div className="w-full bg-white rounded-lg shadow dark:border md:mt-0 sm:max-w-md xl:p-0 dark:bg-gray-800 dark:border-gray-700">
            <div className="p-6 space-y-4 md:space-y-6 sm:p-8">
              <Form saveUserData={saveUserData} />
            </div>
          </div>
        </div>
      </section>
    </main>
  );
};
export default Page;