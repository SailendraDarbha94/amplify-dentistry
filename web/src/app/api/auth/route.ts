import { auth } from "@/lib/firebase"
import { browserLocalPersistence, setPersistence, signInWithEmailAndPassword } from "firebase/auth"

export async function POST(req:Request) {




    const body = await req.json()

    console.log(body)


    const res = await setPersistence(auth, browserLocalPersistence).then(() => {
        return signInWithEmailAndPassword(auth, body.email, body.password)
    })


    if(res.user){
        return Response.json({ data : "success"})
    } else {
        return Response.json({ data : "error"})
    }
    
}