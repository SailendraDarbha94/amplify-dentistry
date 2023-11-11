"use client";
import {
  QuestionItem,
  anatomyQuestions,
  orthodonticQuestions,
  publicHealthQuestions,
} from "@/config/mcqs";
import { useToast } from "@/components/ui/use-toast";
import { useEffect, useLayoutEffect, useState } from "react";
import Question from "@/components/Question";
import { createContext } from "vm";
import { PROMPT } from "@/config/prompts";
import { Button } from "@/components/ui/button";
import { openai } from "@/lib/openai";
import { Loader2 } from "lucide-react";

const Page = () => {
  const [res, setRes] = useState<QuestionItem[]>()
  const [loading, setLoading] = useState<boolean>(false)
  const questioner = async () => {
    setLoading(true)
    const response =  await fetch('/api/questions', {
      method: 'POST',
    })
    //console.log(response)
    //console.log("hello")
    if(response.status === 200){
      setLoading(false)
      const data:QuestionItem[] = await response.json()
      setRes(data)
    }
  };

  const [grade, setGrade] = useState<string>("N/A");
  const [marks, setMarks] = useState<number>(0);

  const apicall = () => {
    questioner();
  };
  useEffect(() => {
    switch (marks) {
      case 2:
        setGrade("F");
        break;
      case 4:
        setGrade("E");
        break;
      case 8:
        setGrade("D");
        break;
      case 12:
        setGrade("C");
        break;
      case 16:
        setGrade("B");
        break;
      case 18:
        setGrade("A");
        break;
      // default:
      //   setGrade('N/A')
      //   break
    }
  }, [grade, marks]);
  const addMarks = () => {
    setMarks((marks) => marks + 2);
  };
  return (
    <div className="flex-1 justify-between flex flex-col h-[calc(100vh-3.5rem)]">
      <div className="mx-auto w-full max-w-8xl grow lg:flex lg:px-1 xl:px-2">
        {/* TODO: create years component */}
        <div className="w-full text-center">
          <Button onClick={apicall}>
            {loading ? (
              <Loader2 />
            ) : (
              <p>
                Call
              </p>
            )}
          </Button>
          <div className="sticky h-14 top-0 z-40 bg-blue-600 rounded-lg p-2 text-white flex justify-between mx-4 md:mx-14">
            <h2 className="text-xl p-2">Grade : {grade}</h2>
            <h2 className="text-xl p-2">Total Marks : {marks}</h2>
          </div>
          {publicHealthQuestions.map((question: QuestionItem) => {
            return (
              <Question key={question.id} {...question} addMarks={addMarks} />
            );
          })}
        </div>
      </div>
    </div>
  );
};

export default Page;
