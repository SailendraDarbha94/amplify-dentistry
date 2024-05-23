// import auth  from "@/lib/firebase"
// import { browserLocalPersistence, setPersistence, signInWithEmailAndPassword } from "firebase/auth"
// import { redirect } from "next/navigation"
// import { cookies } from "next/headers"
// export async function POST(req:Request) {




//     const body = await req.json()

//     console.log(body)


//     const res = await setPersistence(auth, browserLocalPersistence).then(() => {
//         return signInWithEmailAndPassword(auth, body.email, body.password)
//     })


//     if(res.user){
//         cookies().set('refresh_token', res.user.refreshToken, {
//             httpOnly: false,
//             secure: process.env.NODE_ENV === 'development',
//             maxAge: 50,
//             path:'/home'
//         })
//         cookies().set('user_id', res.user.uid, {
//             httpOnly: false,
//             secure: process.env.NODE_ENV === 'development',
//             maxAge: 50000,
//             path:'/home'
//         })
//         console.log("cookies set")
//         //redirect('/home')
//         return Response.json({ data : "success"})
//     } else {
//         return Response.json({ data : "error"})
//     }
    
// }
