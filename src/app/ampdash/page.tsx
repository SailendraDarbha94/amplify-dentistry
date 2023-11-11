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

import { Button } from "@/components/ui/button";
import { openai } from "@/lib/openai";
import { Loader2 } from "lucide-react";
import { promptsGenerator } from "@/lib/utils";
import Skeleton from "react-loading-skeleton";
interface Questions {
  questions: QuestionItem[]
}
const Page = () => {
  
  const subject = "Anatomy of the head and neck"
  const [res, setRes] = useState<QuestionItem[]>()
  const questioner = async (query:string) => {

    const response =  await fetch('/api/questions', {
      method: 'POST',
      body: JSON.stringify(promptsGenerator(query))
    })

    if(response.status === 200){

      const data:Questions = await response.json()
      setRes(data.questions)
    }
  };


  const [grade, setGrade] = useState<string>("N/A");
  const [marks, setMarks] = useState<number>(0);

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
          <div className="sticky h-14 top-0 z-40 bg-blue-600 rounded-lg p-2 text-white flex justify-between mx-4 md:mx-14">
            <h2 className="text-xl p-2">Grade : {grade}</h2>
            <h2 className="text-xl p-2">Total Marks : {marks}</h2>
          </div>
          {res ? (res.map((question: QuestionItem) => {
            return (
              <Question key={question.id} {...question} addMarks={addMarks} />
            );
          })) : <Skeleton height={100} className="my-2" count={3} />}
        </div>
      </div>
    </div>
  );
};

export default Page;
