import app from "@/lib/firebase"
import { getAuth } from "firebase/auth"

export async function POST(req:Request) {
    let res:any = null;
    try {
        const auth = getAuth(app)
        await auth.signOut().then(() => {
            res = Response.json({ data: "success"})
        })
        if(res){
            return res;
        }
    } catch (err) {
        console.log(err)
        return Response.json({ data: "error"})
    }
    
}
