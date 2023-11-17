
//@ts-nocheck
import { db } from "@/db";
import { openai } from "@/lib/openai";
import { getPineconeClient } from "@/lib/pinecone";
import { SendMessageValidator } from "@/lib/validators/SendMessageValidator";
import { getKindeServerSession } from "@kinde-oss/kinde-auth-nextjs/server";
import { OpenAIEmbeddings } from "langchain/embeddings/openai";
import { PineconeStore } from "langchain/vectorstores/pinecone";
import { NextRequest, NextResponse } from "next/server";

import { OpenAIStream, StreamingTextResponse } from "ai";
import OpenAI from "openai";


const openais = new OpenAI();

export const maxDuration = 300;


export const POST = async (req: NextRequest) => {
  // endpoint for asking a prompting ai to get 10 mcqs
  // const PROMPT = `quickly generate 10 quiz questions in the subject of Anatomy aimed at 
  // dental students in this JSON format  
  // {
  //   questions : {
  //     id: 1,
  //     question: "multiple choice question",
  //     answer: "text content of answer",
  //     options: [ "option 1", "option 2", "option 3", "option 4" ]
  //     } 
  // }
  // make sure that the options should not have more than 2-3 words in them,
  // make sure that the answer is strictly matching the correct option`
  //testing somthing above
  const body = await req.json();
  //console.log("req.json = ",body)

  //console.log("json version", body)
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
  let responser:any = null

    const completion = await openais.chat.completions.create({
      messages: [
        {
          role: "system",
          content: "You are a helpful assistant designed to output JSON.",
        },
        { role: "user", content: body },
      ],
      model: "gpt-3.5-turbo-1106",
      response_format: { type: "json_object" },
      stream: false
    });
    if(completion.choices[0].message.content?.length != 0){
      //console.log(completion.choices[0].message.content)
      responser = await JSON.stringify(completion.choices[0].message.content)
      return new Response(responser)
    } else {
      return new Response("Error Generating quiz", { status: 500 });
    }
  
  // const response = await openai.chat.completions.create({
  //   model: 'gpt-3.5-turbo',
  //   temperature: 0.7,
  //   stream: true,
  //   messages: [
  //     {
  //       role: 'system',
  //       content:
  //         'Use the following pieces of context to answer the users question in JSON format.',
  //     },
  //     {
  //       role: 'user',
  //       //content: `Use the following pieces of context (or previous conversaton if needed) to answer the users question in markdown format. \nIf you don't know the answer, just say that you don't know, don't try to make up an answer.
  //       content: body,
  //     },
  //   ],
  // })
  //let data:any;
  // const stream = OpenAIStream(response, {
  //   async onCompletion(completion) {
  //       data = await JSON.parse(completion)
  //   console.log("completed message: ", completion)
  //     await db.message.create({
  //       data: {
  //         text: completion,
  //         isUserMessage: false,
  //         fileId,
  //         userId,
  //       },
  //     })
  //   },
  // })
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
  //return new NextResponse(responser, {status: 200});
  //return new StreamingTextResponse(stream)
  //return new Response.json(responser)
};



