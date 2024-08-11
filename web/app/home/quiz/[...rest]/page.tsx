"use client";
import QuizItem from "@/components/quizItem";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { useParams } from "next/navigation";
import { useEffect, useState } from "react";
const Page = () => {
  const [loading, setLoading] = useState<boolean>(false);
  const [quiz, setQuiz] = useState<any[] | null>(null);
  const { rest } = useParams();

  const quizGenerator = async () => {
    setLoading(true);
    try {
      const genAI = new GoogleGenerativeAI(
        process.env.NEXT_PUBLIC_GEMINI_KEY as string
      );
      const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });
      const prompt = `You are an assistant professor at a University of Dental Sciences, you are very knowledgeable and your task is to create multiple choice questions, return the data in JSON format, here is a sample representation of that { quiz : [ { id : 1, question: "some question", answer: "correct answer", options: ["option one", "option two", "option three", "option four"] } ] }, you have to start the id of the objects inside the quiz array at 1 and auto increment it, you have to create only four options per question, you have make sure that only correct option exists per question, you have to make sure that the options do not have more than 2 to 3 words in them, you have to avoid silly grammatical mistakes, the correct answer should match only one of the options, now create a quiz with ${rest[1]} questions in the quiz array related to the subject of ${rest[0]}`;
      const result: any = await model.generateContent(prompt);
      const text = await result.response.text();

      const newText = await text.split("json")[1];

      const stringToParse = await newText.replace("```", "");

      const { quiz } = JSON.parse(stringToParse);
      //console.log(quiz)
      setQuiz(quiz);

      setLoading(false);
    } catch (err) {
      console.log(JSON.stringify(err));
    }
  };

  useEffect(() => {
    quizGenerator();
  }, [rest]);

  return (
    <div className="w-full min-h-screen">
      {loading ? (
        <div className="w-full min-h-96 flex justify-center items-center">
          <p>loading...</p>
        </div>
      ) : (
        <div>
          <p>subject is {rest[0]}</p>
          <p>number of questions to generate is {rest[1]}</p>
        </div>
      )}
      <div>
        {quiz ? (
          <div>
            {quiz.map((item: any) => {
              return (
                <div key={item.id}>
                  <QuizItem {...item} />
                </div>
              );
            })}
          </div>
        ) : null}
      </div>
    </div>
  );
};

export default Page;
