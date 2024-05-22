"use client"

import { auth } from "@/lib/firebase";
import { onAuthStateChanged, signOut } from "firebase/auth";
import { useContext, useEffect } from "react";
import { UserContext } from "../layout";


const Page = () => {

    const authChecker = async () => {
        await onAuthStateChanged(auth, user => {
            console.log("userdata",user)
        })
    }

    const author = auth.currentUser

    useEffect(() => {
        authChecker()
    },[])

    return (
        <div className="min-h-screen">
            <h1>win</h1>
            <button onClick={() => {
                signOut(auth).then(() => {
                    console.log("signed out")
                })
            }}>signout</button>
        </div>
    )
}

export default Page