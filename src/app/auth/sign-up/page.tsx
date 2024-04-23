"use client";
import { useAuthContext } from "@/context/AuthContext";
import firebase_app from "@/firebase/config";
import { Button } from "@nextui-org/react";
import {
  getAuth,
  signInWithRedirect,
  getRedirectResult,
  GoogleAuthProvider,
} from "firebase/auth";
import { useContext, useEffect } from "react";
const Page = () => {
  const auth = getAuth(firebase_app);
  const provider = new GoogleAuthProvider();

  const authenticator = () => {
    signInWithRedirect(auth, provider);
    
  };

  const logger = () => {
    getRedirectResult(auth)
      .then((result: any) => {
        // This gives you a Google Access Token. You can use it to access Google APIs.
        const credential = GoogleAuthProvider.credentialFromResult(result);
        const token = credential?.accessToken;
        console.log(token)
        // The signed-in user info.
        const user = result?.user;
        console.log(user)
        // IdP data available using getAdditionalUserInfo(result)
        // ...
      })
      .catch((error:any) => {
        // Handle Errors here.
        const errorCode = error.code;
        const errorMessage = error.message;
        console.log(errorCode, errorMessage)
        // The email of the user's account used.
        //const email = error.customData.email;
        // The AuthCredential type that was used.
        const credential = GoogleAuthProvider.credentialFromError(error);
        // ...
      });
  };

  useEffect(() => {
    console.log(auth.currentUser)
  }, []);

  const logouter = async () => {
    const res = await auth.signOut()
    if(res !== undefined){
        console.log(res)
    }
  }
  const { user }:any = useAuthContext()
  const sessioner = async () => {
    console.log("author", auth.currentUser)
    console.log("user",user)
  }

  return (
    <div className="w-full min-h-screen bg-red-100 flex justify-center p-10">
      <div className="min-w-40 bg-red-200">
        <h1 className="text-2xl">Sign-Up</h1>
        <Button
          onClick={authenticator}
          color="primary"
          size="lg"
          className="m-2 p-2 rounded-xl"
        >
          Click me
        </Button>
        <Button
          onClick={logouter}
          color="primary"
          size="lg"
          className="m-2 p-2 rounded-xl"
        >
          Click me to sign out
        </Button>
        <Button
          onClick={sessioner}
          color="primary"
          size="lg"
          className="m-2 p-2 rounded-xl"
        >
          Click sessions
        </Button>
      </div>
    </div>
  );
};

export default Page;
