"use client";

import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Toast } from "@/components/ui/toast";
import { useToast } from "@/components/ui/use-toast";
import { useContext, useState } from "react";

const Question = ({ question, answer, options, addMarks, attemptQ }: {question:string, answer:string, options:string[], addMarks:Function, attemptQ: Function }) => {

  const [answered, setAnswered] = useState<boolean>(false);
  const [correctAnswered, setCorrectAnswered] = useState<boolean>(false);

  const { toast } = useToast();

  const checkAnswer = async (ans: string) => {
    attemptQ()
    setAnswered(true);
    if (ans === answer) {
      setCorrectAnswered(true);
      addMarks()
      toast({
        title: "Correct answer",
        description: "You got 2 marks",
      });
    } else {
      toast({
        title: "Wrong answer",
        description: "Try again",
      });
    }
  };

  return (
    <div className="flex-1 justify-between flex flex-col">
      <div className="mx-auto w-full max-w-8xl grow lg:flex lg:px-1 xl:px-2">
        {/* TODO: create years component */}
        <div className="w-full text-center">
          <Card className="md:mx-12 mt-4 mx-2">
            <CardHeader>
              {/* <CardTitle className="mr-auto">Question</CardTitle> */}
              <CardDescription className="text-lg">
                {question}
              </CardDescription>
            </CardHeader>
            {!answered ? (
              <CardContent>
                <div className="flex flex-wrap justify-center">
                  {options.map((option) => {
                    return (
                      <Button
                        key={option}
                        className="md:w-1/3 w-full m-2 p-2"
                        onClick={(e: any) => {
                          checkAnswer(e.target.textContent);
                        }}
                      >
                        {option}
                      </Button>
                    );
                  })}
                </div>
              </CardContent>
            ) : null}
            <CardFooter className="justify-center">
              {answered ? (
                correctAnswered ? (
                  <p className="bg-green-300 rounded-lg p-2 text-black shadow-lg">
                    {/* {answer} */}
                    Correct Answer
                  </p>
                ) : (
                  <p className="bg-red-400 rounded-lg p-2 text-black shadow-lg">
                    Wrong! <br /> Correct Answer : {answer}
                  </p>
                )
              ) : null}
            </CardFooter>
          </Card>
        </div>
      </div>
    </div>
  );
};

export default Question;
