"use client";
import { OpenAI } from "openai";

import { OpenAIStream, StreamingTextResponse } from "ai";
import { Button, Input, Spinner } from "@nextui-org/react";
import { useEffect, useState } from "react";

const SimpleChatter = () => {
  const [prompt, setPrompt] = useState<string>("");
  const [loading, setLoading] = useState<boolean>(false);
  const [answer, setAnswer] = useState<string>("");
  const openAi = new OpenAI({
    apiKey: process.env.NEXT_PUBLIC_OPENAI_API_KEY,
    dangerouslyAllowBrowser: true,
  });

  const testFunction = async () => {
    setLoading(true);
    try {
      //   const completion = await openAi.completions.create({
      //     model: "gpt-3.5-turbo-instruct",
      //     prompt: prompt,
      //     max_tokens: 200,
      //     temperature: 0.5,
      //     presence_penalty: 0,
      //     frequency_penalty: 0,
      //   });
      const completion = await openAi.chat.completions.create({
        model: "gpt-3.5-turbo",
        stream: false,
        temperature: 0.5,
        messages: [
          {
            role: "system",
            content:
              "You are a Dental Assistant ChatBot that answers any doubts regarding the field of dentistry but politely declines and questions not related to Dentistry",
          },
          {
            role: "user",
            content: prompt,
          },
        ],
      });
      setLoading(false);
      const answer = await completion.choices[0].message.content;
      setAnswer(answer!);
      setPrompt("");
      console.log(completion.choices[0].message.content);
    } catch (err) {
      console.log(err);
      setPrompt("");
      setLoading(false);
    }
  };

  return (
    <div className="w-full h-full relative rounded-xl p-2 flex flex-col justify-end items-center">
      {loading ? <p>Loading...</p> : null}
      {answer ? (
        <div className="w-full my-4 text-justify text-md px-4">{answer}</div>
      ) : null}
      <Input
        value={prompt}
        size="lg"
        onChange={(e: any) => setPrompt(e.target.value)}
        placeholder="Enter your question"
      />
      <Button
        className="px-2 mt-2 w-20 h-10 rounded-md"
        color="primary"
        variant="solid"
        size="lg"
        onClick={testFunction}
      >
        Ask
      </Button>
    </div>
  );
};

export default SimpleChatter;
