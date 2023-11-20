
import { db } from "@/db";
import { getKindeServerSession } from "@kinde-oss/kinde-auth-nextjs/server";

import { NextRequest, NextResponse } from "next/server";


export const POST = async (req: NextRequest) => {

  const { title, notice, mail } = await req.json();
  //console.log("req.json = ",body)

  //console.log("json version", body)
  const { getUser } = getKindeServerSession();
  const user = getUser();

  const { id: userId } = user;

  if (!userId) return new Response("Unauthorized", { status: 401 });
  const res = await db.notice.create({
    data: {
      title,
      notice,
      author: mail?.split("@")[0],
    },
  });

  //   const { fileId, message } =
  //     SendMessageValidator.parse(body)

  //   const file = await db.file.findFirst({
  //     where: {
  //       id: fileId,
  //       userId,
  //     },
  //   })

  //   if (!file)
  //     return new Response('Not found', { status: 404 })

  //   await db.message.create({
  //     data: {
  //       text: message,
  //       isUserMessage: true,
  //       userId,
  //       fileId,
  //     },
  //   })
  //let responser:any = null

    return new Response(JSON.stringify(res))
};
