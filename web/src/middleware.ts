import { getAuth, onAuthStateChanged } from "firebase/auth";
import { NextRequest, NextResponse } from "next/server";
import app from "./lib/firebase";


export async function middleware(request:NextRequest){
    const baseUrl:string = "http://localhost:3000/";
    let authenticatedUser:any|null = null;
    const auth = getAuth(app);
    onAuthStateChanged(auth,user => {
        authenticatedUser = user;
    })
    console.log("middle ware triggered by", authenticatedUser)
    // if(!authenticatedUser){
    //     return NextResponse.redirect(baseUrl + "auth/login")
    // }
    let response = NextResponse.next();
    response.headers.set('X-Custom-Header', 'Approved by Middleware!');
    // response.cookies.set('user', authenticatedUser)
    return response
}


export const config = {
    matcher: ['/home']
}