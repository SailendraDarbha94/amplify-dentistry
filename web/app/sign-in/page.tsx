"use client";

import app from "@/config/firebase";
import { Input } from "@nextui-org/input";
import {
  browserLocalPersistence,
  getAuth,
  setPersistence,
  signInWithEmailAndPassword,
} from "firebase/auth";
import { useContext, useState } from "react";
import { ToastContext } from "../providers";
import { useRouter } from "next/navigation";
import { Button } from "@nextui-org/button";

const Page = () => {
  const [email, setEmail] = useState<string>("");
  const [password, setPassword] = useState<string>("");
  const [loading, setLoading] = useState<boolean>(false);

  const router = useRouter();
  const { toast } = useContext(ToastContext);
  const loginUser = async () => {
    setLoading(true);
    const auth = getAuth(app);

    setPersistence(auth, browserLocalPersistence).then(() => {
      signInWithEmailAndPassword(auth, email, password)
        .then((cb) => {
          console.log(cb);
          if (cb.user) {
            // TODO ADD TOAST
            toast({
              message: "User Logged In! Redirecting",
              type: "success",
            });
            setTimeout(() => {
              router.push("/home");
            }, 1500);
            setLoading(false);
          }
        })
        .catch((err) => {
          console.log("Error Occured", JSON.stringify(err));
          toast({
            message: `An Error Occurred! ${err.code}`,
            type: "error",
          });
        });
    });
  };

  return (
    <div className="w-full min-h-fit p-2 md:p-4">
      <div className="w-full max-w-md mx-auto">
        <h1 className="text-2xl font-bold text-center my-4">Login</h1>
        <Input
          className="my-2"
          label="Email"
          type="email"
          onChange={(e) => setEmail(e.target.value)}
        />
        <Input
          className="my-2"
          label="Password"
          type="password"
          onChange={(e) => setPassword(e.target.value)}
        />
        <br />
        <p className="text-sm font-semibold text-center">
          Don&apos;t have an account ? <a className="text-medium text-blue-500 underline" href="/sign-up">Sign-up</a>
        </p>
        <br />
        <Button
          className="block mx-auto my-4"
          color="primary"
          variant="shadow"
          onPress={loginUser}
        >
          Login
        </Button>
      </div>
    </div>
  );
};

export default Page;
