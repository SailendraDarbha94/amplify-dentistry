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
import { useState } from "react";

const Page = () => {
  const options: string[] = ["Class I", "Class II", "Class III", "NOTA"];
  const answer = "Class II";
  const [answered, setAnswered] = useState<boolean>(false);
  const [correctAnswered, setCorrectAnswered] = useState<boolean>(false);
  const { toast } = useToast();
  const checkAnswer = async (ans: string) => {
    setAnswered(true);
    if (ans === answer) {
      setCorrectAnswered(true);
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
    <div className="flex-1 justify-between flex flex-col h-[calc(100vh-3.5rem)]">
      <div className="mx-auto w-full max-w-8xl grow lg:flex lg:px-1 xl:px-2">
        {/* TODO: create years component */}
        <div className="bg-red-300 w-full text-center">
          <Card className="md:mx-12">
            <CardHeader>
              <CardTitle>Question</CardTitle>
              <CardDescription className="text-lg">
                a dental arch relation where the lower dental arch is positioned
                posteriorly in relation to the upper dental arch
              </CardDescription>
            </CardHeader>
            {!answered ? (
              <CardContent>
                <div className="flex flex-wrap justify-center">
                  {/* {options.map((option) => {
                return (
                  <Button className="w-1/3 m-2 p-2" onClick={(e:any) => checkAnswer(e.target.textContent)}>
                    {option}
                  </Button>
                )
              })} */}
                  <Button
                    className="w-1/3 m-2 p-2"
                    onClick={(e: any) => {
                      checkAnswer(e.target.textContent);
                    }}
                  >
                    Class I
                  </Button>
                  <Button
                    className="w-1/3 m-2 p-2"
                    onClick={(e: any) => {
                      checkAnswer(e.target.textContent);
                    }}
                  >
                    Class II
                  </Button>
                  <Button
                    className="w-1/3 m-2 p-2"
                    onClick={(e: any) => {
                      checkAnswer(e.target.textContent);
                    }}
                  >
                    Class III
                  </Button>
                  <Button
                    className="w-1/3 m-2 p-2"
                    onClick={(e: any) => {
                      checkAnswer(e.target.textContent);
                    }}
                  >
                    None of the above
                  </Button>
                </div>
              </CardContent>
            ) : null}
            <CardFooter className="justify-center">
              {answered ? (
                correctAnswered ? (
                  <p className="bg-green-300 rounded-lg p-2 text-black shadow-lg">
                    Correct Answer
                  </p>
                ) : (
                  <p className="bg-red-400 rounded-lg p-2 text-black shadow-lg">
                    Wrong Answer
                  </p>
                )
              ) : null}
            </CardFooter>
          </Card>
        </div>
      </div>
      <div className="bg-red-400">world</div>
    </div>
  );
};

export default Page;
