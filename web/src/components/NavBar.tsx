"use client";

import app from "@/lib/firebase";
import { ToastContext } from "@/providers/ToastContextProvider";
import { getAuth, signOut } from "firebase/auth";
import { usePathname, useRouter } from "next/navigation";
import { useContext, useState } from "react";

const NavBar = () => {
  const router = useRouter();
  const path = usePathname();

  const { toast } = useContext(ToastContext);

  const [loading, setLoading] = useState<boolean>(false);

  const allowedPaths: string[] = ["/home"];

  const logouter = async () => {
    setLoading(true);
    const auth = await getAuth(app);
    try {
      await signOut(auth);
      await toast({
        message: "User Logged Out!",
        type: "success",
      });
      setLoading(false);
      router.push("/");
    } catch (err) {
      setLoading(false);
      toast({
        message: "An Erroc Occured! Please try again later",
        type: "error",
      });
      console.log(err);
    }
  };

  return (
    <>
      {allowedPaths.includes(path) ? (
        <>
          <div
            id="topNavBar"
            className="bg-transparent z-10 text-black shadow-lg h-14 hidden md:flex m-2 items-center justify-between rounded-xl"
          >
            <a
              href="#"
              className="h-full p-2 rounded-tl-xl rounded-bl-xl border-r-2 border-black flex items-center bg-navbar"
            >
              <img src="/logo-image.png" alt="logo" className="h-full w-10" />
              <p className=" font-pBold">AmplifyDentistry</p>
            </a>
            <div className="h-full rounded-tr-xl font-pSemiBold rounded-br-xl border-l-2 border-black flex items-center z-30 bg-navbar">
              <button
                className="border-r-2 border-black h-full px-3"
                onClick={() => router.push("/test-view")}
              >
                Profile
              </button>
              <button className="h-full px-3" onClick={logouter}>
                {loading ? <div>Loading...</div> : <span>Logout</span>}
              </button>
            </div>
          </div>

          {/* BOTTOM NAVBAR */}
          <div
            id="bottomNavBar"
            className="bg-transparent z-10 bg-sky-200 text-black fixed items-center bottom-2 left-0 border-2 border-black shadow-md m-2 h-14 flex md:hidden w-[96%] self-center justify-between rounded-xl"
          >
            <a
              href="#"
              className="h-full p-2 rounded-tl-lg rounded-bl-lg border-r-2 border-black flex items-center "
            >
              <img src="/logo-image.png" alt="logo" className="h-full w-10" />
            </a>
            <div className="h-full rounded-tr-lg font-pSemiBold rounded-br-lg border-l-2 border-black flex items-center">
              <button
                className="border-r-2 border-black h-full px-3"
                onClick={() => router.push("/test-view")}
              >
                Profile
              </button>
              <button className="h-full px-3" onClick={logouter}>
                {loading ? <div>Loading...</div> : <span>Logout</span>}
              </button>
            </div>
          </div>
        </>
      ) : null}
      {/* TOP NAVBAR */}
    </>
  );
};

export default NavBar;
