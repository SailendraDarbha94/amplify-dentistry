import { useToast } from '@/components/ui/use-toast';
import { db } from '@/db'


import { getKindeServerSession } from '@kinde-oss/kinde-auth-nextjs/server'

import { NextRequest, NextResponse } from 'next/server'

export const POST = async (req: NextRequest) => {
  // endpoint for asking a question to a pdf file
  const body = await req.json()

  const { getUser } = getKindeServerSession()
  const user = getUser()

  const { id: userId } = user

  if (!userId)
    return new Response('Unauthorized', { status: 401 })


  const res = await db.feedback.create({
    data: {
        userId,
        text: body,
    }})

  if (res) { return new NextResponse('Feedback Received', { status: 200 }) }  else  {return new Response('Not found', { status: 404 }) }
}
