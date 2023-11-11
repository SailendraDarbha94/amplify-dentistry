import { db } from "@/db";
import { openai } from "@/lib/openai";
import { getPineconeClient } from "@/lib/pinecone";
import { SendMessageValidator } from "@/lib/validators/SendMessageValidator";
import { getKindeServerSession } from "@kinde-oss/kinde-auth-nextjs/server";
import { OpenAIEmbeddings } from "langchain/embeddings/openai";
import { PineconeStore } from "langchain/vectorstores/pinecone";
import { NextRequest, NextResponse } from "next/server";

import { OpenAIStream, StreamingTextResponse } from "ai";
import { PROMPT } from "@/config/prompts";

export const POST = async (req: NextRequest) => {
  // endpoint for asking a prompting ai to get 10 mcqs

  //const body = await req.json();
  //console.log(body)
  const { getUser } = getKindeServerSession();
  const user = getUser();

  const { id: userId } = user;

  if (!userId) return new Response("Unauthorized", { status: 401 });

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
  const response = await openai.chat.completions.create({
    model: 'gpt-3.5-turbo',
    temperature: 0.8,
    stream: true,
    messages: [
      {
        role: 'system',
        content:
          'Use the following pieces of context to answer the users question in JSON format.',
      },
      {
        role: 'user',
        //content: `Use the following pieces of context (or previous conversaton if needed) to answer the users question in markdown format. \nIf you don't know the answer, just say that you don't know, don't try to make up an answer.
        content: PROMPT,
      },
    ],
  })
  //let data:any;
  const stream = OpenAIStream(response, {
    async onCompletion(completion) {
        //data = await JSON.parse(completion)
    //console.log("completed message: ", completion)
    //   await db.message.create({
    //     data: {
    //       text: completion,
    //       isUserMessage: false,
    //       fileId,
    //       userId,
    //     },
    //   })
    },
  })
  // 1: vectorize message
  //   const embeddings = new OpenAIEmbeddings({
  //     openAIApiKey: process.env.OPENAI_API_KEY,
  //   })

  //   const pinecone = await getPineconeClient()
  //   const pineconeIndex = pinecone.Index('amplifydentistry')

  //   const vectorStore = await PineconeStore.fromExistingIndex(
  //     embeddings,
  //     {
  //       pineconeIndex,
  //       namespace: file.id,
  //     }
  //   )

  //   const results = await vectorStore.similaritySearch(
  //     message,
  //     4
  //   )

  //   const prevMessages = await db.message.findMany({
  //     where: {
  //       fileId,
  //     },
  //     orderBy: {
  //       createdAt: 'asc',
  //     },
  //     take: 6,
  //   })

  //   const formattedPrevMessages = prevMessages.map((msg) => ({
  //     role: msg.isUserMessage
  //       ? ('user' as const)
  //       : ('assistant' as const),
  //     content: msg.text,
  //   }))

//   const response = await openai.chat.completions.create({
//     model: "gpt-3.5-turbo",
//     temperature: 0.8,
//     stream: false,
//     messages: [
//       {
//         role: "system",
//         content:
//           "Use the following pieces of context to answer the users question in JSON format.",
//       },
//       {
//         role: "user",

//         content: `Use the following pieces of context to answer the users question in JSON format.
        
//   \n----------------\n
  
//   CONTEXT:
  
//   USER INPUT: ${body}`,
//       },
//     ],
//   });

  //   const stream = OpenAIStream(response, {
  //     async onCompletion(completion) {
  //       await db.message.create({
  //         data: {
  //           text: completion,
  //           isUserMessage: false,
  //           fileId,
  //           userId,
  //         },
  //       })
  //     },
  //   })
  //console.log(response);
  //return new NextResponse(data, {status: 200});
  return new StreamingTextResponse(stream)
};



