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
import { toast, useToast } from "@/components/ui/use-toast";

import { useState } from "react";

const Feedback = () => {
  const [submitted, setSubmitted] = useState<boolean>(false);
  const [received, setReceived] = useState<boolean>(false);
  const [feedback, setFeedback] = useState<string>("");

  

  async function submitFeedback() {
    setReceived(true);
    console.log("Submitted feedback : ", feedback);
    try {
      const res = await fetch("api/feedback", {
        method: "POST",
        body: JSON.stringify(feedback),
      });
      if (res) {
        console.log(res);
        setFeedback("");
        setSubmitted(true);
        toast({
            title: 'Feedback Received',
            description: 'Thank you for feedback',
        })
      }
    } catch (error) {
      console.error(error);
    }
  }

  //   const checkAnswer = async (ans: string) => {
  //     setAnswered(true);
  //     if (ans === answer) {
  //       setCorrectAnswered(true);
  //         addMarks()
  //       toast({
  //         title: "Correct answer",
  //         description: "You got 2 marks",
  //       });
  //     } else {
  //       toast({
  //         title: "Wrong answer",
  //         description: "Try again",
  //       });
  //     }
  //   };

  return (
    <div className="flex-1 justify-between flex flex-col">
      <div className="mx-auto w-full max-w-8xl grow lg:flex lg:px-1 xl:px-2">
        {received ? (
          <p className="bg-green-300 rounded-lg p-4 text-black shadow-xl w-1/2 text-center mx-auto mt-10">
            {/* {answer} */}
            Feedback Received
          </p>
        ) : (
          <div className="w-full text-center">
            <Card className="md:mx-12 mt-4 mx-2">
              <CardHeader>
                <CardTitle className="mx-auto">Feedback Form</CardTitle>
                <CardDescription className="text-lg">
                  Please keep your feedback short and simple
                </CardDescription>
              </CardHeader>
              <CardContent>
                <div className="flex flex-wrap justify-center">
                  <textarea
                    name="feedback"
                    id="feedback"
                    rows={10}
                    className="border-2 border-blue-300 w-full rounded-lg p-2 m-2"
                    onChange={(e: any) => setFeedback(e.target.value)}
                    value={feedback}
                  ></textarea>
                  <Button
                    className="md:w-1/3 w-full m-2 p-2"
                    onClick={(e: any) => {
                      submitFeedback();
                    }}
                  >
                    Submit
                  </Button>
                </div>
              </CardContent>
              <CardFooter className="justify-center">
                {submitted && (
                  <p className="bg-red-400 rounded-lg p-2 text-black shadow-lg">
                    Feedback Submitted
                  </p>
                )}
              </CardFooter>
            </Card>
          </div>
        )}
      </div>
    </div>
  );
};

export default Feedback;
