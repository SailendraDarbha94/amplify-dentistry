"use client";
import { useAuthContext } from "@/context/AuthContext";
import firebase_app from "@/firebase/config";
import {
  Button,
  Card,
  CardBody,
  CardFooter,
  CardHeader,
  Divider,
  Link,
} from "@nextui-org/react";
import {
  getAuth,
  signInWithRedirect,
  getRedirectResult,
  onAuthStateChanged,
  GoogleAuthProvider,
} from "firebase/auth";
import { useRouter } from "next/navigation";
import { useContext, useEffect } from "react";
const Page = () => {
  const auth = getAuth(firebase_app);
  const provider = new GoogleAuthProvider();
  const { user }: any = useAuthContext();
  const authenticator = () => {
    signInWithRedirect(auth, provider);
  };
  const router = useRouter()
  const checkUser = async () => {
    if(auth.currentUser){
        router.push("/test-view")
    }
  }
  useEffect(() => {
    checkUser()
  },[auth])

  const logger = () => {
    getRedirectResult(auth)
      .then((result: any) => {
        // This gives you a Google Access Token. You can use it to access Google APIs.
        const credential = GoogleAuthProvider.credentialFromResult(result);
        const token = credential?.accessToken;
        console.log(token);
        // The signed-in user info.
        const user = result?.user;
        console.log(user);
        // IdP data available using getAdditionalUserInfo(result)
        // ...
      })
      .catch((error: any) => {
        // Handle Errors here.
        const errorCode = error.code;
        const errorMessage = error.message;
        console.log(errorCode, errorMessage);
        // The email of the user's account used.
        //const email = error.customData.email;
        // The AuthCredential type that was used.
        const credential = GoogleAuthProvider.credentialFromError(error);
        // ...
      });
  };

//   const logouter = async () => {
//     const res = await auth.signOut();
//     if (res !== undefined) {
//       console.log(res);
//     }
//   };
//   const { user }: any = useAuthContext();
//   const sessioner = async () => {
//     console.log("author", auth.currentUser);
//     console.log("user", user);
//   };

  return (
    <div className="w-full min-h-screen flex justify-center p-10">
      <div className="min-w-40">
        <Card className="max-w-[400px] rounded-lg bg-slate-200 py-4 px-4">
          <CardHeader className="flex gap-3">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="2em"
              height="2em"
              viewBox="0 0 256 262"
            >
              <path
                fill="#4285f4"
                d="M255.878 133.451c0-10.734-.871-18.567-2.756-26.69H130.55v48.448h71.947c-1.45 12.04-9.283 30.172-26.69 42.356l-.244 1.622l38.755 30.023l2.685.268c24.659-22.774 38.875-56.282 38.875-96.027"
              />
              <path
                fill="#34a853"
                d="M130.55 261.1c35.248 0 64.839-11.605 86.453-31.622l-41.196-31.913c-11.024 7.688-25.82 13.055-45.257 13.055c-34.523 0-63.824-22.773-74.269-54.25l-1.531.13l-40.298 31.187l-.527 1.465C35.393 231.798 79.49 261.1 130.55 261.1"
              />
              <path
                fill="#fbbc05"
                d="M56.281 156.37c-2.756-8.123-4.351-16.827-4.351-25.82c0-8.994 1.595-17.697 4.206-25.82l-.073-1.73L15.26 71.312l-1.335.635C5.077 89.644 0 109.517 0 130.55s5.077 40.905 13.925 58.602z"
              />
              <path
                fill="#eb4335"
                d="M130.55 50.479c24.514 0 41.05 10.589 50.479 19.438l36.844-35.974C195.245 12.91 165.798 0 130.55 0C79.49 0 35.393 29.301 13.925 71.947l42.211 32.783c10.59-31.477 39.891-54.251 74.414-54.251"
              />
            </svg>
            <div className="flex flex-col">
              <h1 className="text-lg md:text-2xl text-center my-2">Login With Google</h1>
            </div>
          </CardHeader>
          <Divider />
          <CardBody>
            <p className="text-justify">
              We currently support only Google Provider for safety reasons, but
              we will be adding more options soon.
            </p>
          </CardBody>
          <Divider />
          <CardFooter>
            {/*   <Link
              isExternal
              //showAnchorIcon
              className="block mx-auto"
              href="https://github.com/nextui-org/nextui"
            >
              Visit source code on GitHub.
            </Link> */}
            <Button
              onClick={authenticator}
              color="primary"
              size="lg"
              className="m-2 p-2 rounded-xl mx-auto w-40"
            >
              Login
            </Button>
          </CardFooter>
        </Card>
{/* 
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
        </Button> */}
      </div>
    </div>
  );
};

export default Page;
