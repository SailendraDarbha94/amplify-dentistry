
import OpenAI from "openai";

export async function POST(req: Request, res: Response) {
  const prompt = await req.json();
  console.log(prompt._prompt);
  const openai =  await  new OpenAI({ apiKey: process.env.NEXT_PUBLIC_OPENAI_API_KEY!});
  const completion = await openai.chat.completions.create({
    messages: [{ role: "system", content: "You are a helpful assistant." }, { role : "user", content: prompt._prompt}],
    model: "gpt-4o",
  });

   return Response.json({ data : completion})
  //return Response.json({ data: "success"})
}