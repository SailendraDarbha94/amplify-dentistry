"use client";


import { useContext, useEffect, useState } from "react";
import Link from "next/link";

import { useRouter } from "next/navigation";
//import { cookies } from "next/headers";
const Page = () => {
  const [token, setToken] = useState<any>(null);
//   const getCookie = (name: any) => {
//     const value = `; ${document.cookie}`;
//     const parts: any = value.split(`; ${name}=`);
//     if (parts.length === 2) return parts.pop().split(";").shift();
//   };
  const router = useRouter();

  const signOutUser = async () => {
    const res = await fetch('/api/auth/logout', {
        method: "POST",

    })
    const { data } = await res.json()
    console.log(data)
  }

const cookieFunc = async () => {
    const cookieArrays = document.cookie.split(';')
    let cookieObj = {};
    cookieArrays.forEach((cookie) => {
        const tempArr = cookie.split('=')
        const tempArrKey = tempArr[0].toString()
        return (
            cookieObj =  { ...cookieObj , [tempArrKey] : tempArr[1] }
        )
    })
    return cookieObj
}



const getnewtoken = async (newtoken:string) => {
    const res = await fetch('https://securetoken.googleapis.com/v1/token?key=AIzaSyBVUwTCTvah5wRiiIxDun8YpMfeRYaQPqo', {
        method: "POST",
        body: JSON.stringify({
            "grant_type":"refresh_token",
            "refresh_token": newtoken
        })
    })
    const data = await res.json()
    console.log("new token",data)
}

  useEffect(() => {
    cookieFunc().then((data:any) => {
        if(data && !token){
            setToken(data.refresh_token)
            console.log(token)
        } else {
            console.log(token)
            getnewtoken(token)
        }
    })
  }, [token]);

  return (
    <div className="min-h-screen">
      <h1>win</h1>
      <button
        onClick={signOutUser}
      >
        signout
      </button>

      

      <Link href={"/"}>home</Link>
    </div>
  );
};

export default Page;
