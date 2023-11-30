"use client";
import { getKindeServerSession } from "@kinde-oss/kinde-auth-nextjs/server";
import {
  createContext,
  useContext,
  useEffect,
  useLayoutEffect,
  useState,
} from "react";
import { promptsGenerator } from "@/lib/utils";
import { QuestionItem } from "@/config/mcqs";
import Question from "@/components/Question";
import Skeleton from "react-loading-skeleton";
import { Progress } from "@/components/ui/progress";
import Grade from "@/components/Grade";
import { MarksContext } from "@/components/MarksContext";
import Link from "next/link";
import { buttonVariants } from "@/components/ui/button";

//export const MarksContext = createContext(0)

interface PageProps {
  params: {
    subject: string;
  };
}

interface Questions {
  questions: QuestionItem[];
}

const Page = ({ params }: PageProps) => {
  const { subject } = params;

  //   const { getUser } = getKindeServerSession();
  //   const user = getUser();

  //   if (!user.id || !user.email) {
  //     throw new Error("User not found");
  //   }

  const [data, setData] = useState<QuestionItem[]>();
  const [bug, setBug] = useState(false);
  const [grade, setGrade] = useState<string>("N/A");
  const [marks, setMarks] = useState<number>(0);
  const [uploadProgress, setUploadProgress] = useState<number>(0);
  const startSimulatedProgress = () => {
    setUploadProgress(0);

    const interval = setInterval(() => {
      setUploadProgress((prevProgress) => {
        if (prevProgress >= 99) {
          clearInterval(interval);
          return prevProgress;
        }
        return prevProgress + 3;
      });
    }, 800);

    return interval;
  };

  const setGrades = async () => {
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
    return null;
  };
  const addMarks = async () => {
    setMarks((marks) => marks + 2);
    setGrades();
  };
  const [testing, setTesting] = useState<boolean>(false);
  const [attempts, setAttempts] = useState<number>(0);
  const attemptQ = async () => {
    setAttempts((attempt: number) => attempt + 1);
    if (attempts === 9) {
      setTesting(true);
    }
  };
  const PROMPT = `generate 10 quiz questions in the subject of ${
    subject.split(".")[0]
  } for 
  dental students in this JSON format as fast as you can  questions : {
  id: 1,
  question: "multiple choice question",
  answer: "text content of answer",
  options: [ "option 1", "option 2", "option 3", "option 4" ]
  }
  make sure that the options should not have more than 2-3 words in them and make sure that the answer matches the correct option`;

  async function fetchData() {
    //const PROPMT = await promptsGenerator(subject.split(".")[0])
    const progressInterval = startSimulatedProgress();
    const response = await fetch("/api/questions", {
      method: "POST",
      body: JSON.stringify(PROMPT),
    });

    if (response.status === 504) {
      setBug(true);
      throw new Error("Timeout Error, please try again");
    }
    if (!response.ok) {
      setBug(true);
      throw new Error("An Error occurred while fetching data");
    }

    if (response.status === 200) {
      //console.log("Success")
      const data = await response.json();
      const sanitized = await JSON.parse(data);
      //console.log(sanitized)
      const questions = await sanitized.questions;
      await setData(questions);
      //console.log(questions)
      clearInterval(progressInterval);
      setUploadProgress(100);
    }
  }

  useEffect(() => {
    //let ignore = false

    //if(!ignore){
    fetchData();
    //}
    //console.log(res)
    //return () => {ignore = true}
  }, []);

  // useEffect(() => {
  //   console.log("effect workign")
  //   console.log(res)
  // },[res])

  return (
    <div className="flex-1 justify-between flex flex-col h-[calc(100vh-3.5rem)]">
      <div className="mx-auto w-full max-w-8xl grow lg:flex lg:px-1 xl:px-2">
        {/* TODO: create years component */}
        {testing ? (
          <div className="w-full text-center font-bold text-3xl mt-24">
            You have finished the quiz !
            <br />
            <p className="m-2 p-2">
              <Link
                href="/dashboard"
                className={buttonVariants({
                  variant: "default",
                  size: "sm",
                })}
              >
                Home
              </Link>
            </p>
          </div>
        ) : (
          <div className="w-full text-center">
            <MarksContext.Provider value={marks}>
              <Grade />
            </MarksContext.Provider>
            {/* {data && data.map((question: QuestionItem) => {
              return (
                <Question key={question.id} {...question} addMarks={addMarks} />
              );
            })} */}
            {data ? (
              data.map((question: QuestionItem) => {
                return (
                  <Question
                    key={question.id}
                    {...question}
                    addMarks={addMarks}
                    attemptQ={attemptQ}
                  />
                );
              })
            ) : (
              <div className="w-full mt-4 max-w-md mx-auto">
                <h3 className="text-xl font-semibold">
                  Please wait a few seconds while we generate new MCQs for you
                </h3>
                <Progress
                  indicatorColor={uploadProgress === 99 ? "bg-green-500" : ""}
                  value={uploadProgress}
                  className="h-1 w-full bg-zinc-200"
                />
                <Skeleton height={100} className="my-2" count={3} />
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
};

export default Page;
