"use client";
import QuizItem from "@/components/quizItem";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { Button } from "@nextui-org/button";
import { Image } from "@nextui-org/image";
import { useParams, useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
const Page = () => {
  const [loading, setLoading] = useState<boolean>(false);
  const [quiz, setQuiz] = useState<any[] | null>(null);
  const { rest } = useParams();
  const router = useRouter();
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
  }, []);

  const [score, setScore] = useState<number>(0);
  const [counter, setCounter] = useState<number>(0);
  const [message, setMessage] = useState<string>("");
  const [quizFinished, setQuizFinished] = useState<boolean>(false);

  const topRef = useRef(null);
  const scrollToRef = (target: any) => {
    window.scrollTo({
      top: target.current.offsetTop - 100,
      behavior: "smooth",
    });
  };

  const doctorRenderer: () => string = () => {
    if (score < 10) {
      setMessage("Are you kidding me?");

      return "/images/angry-doctor.png";
    } else if (score < 18) {
      setMessage("You could do better");

      return "/images/perplexed-doctor.png";
    } else if (score <= 24) {
      setMessage("Well Done");

      return "/images/normal-doctor.png";
    } else {
      setMessage("You bring joy to teachers");

      return "/images/happy-doctor.png";
    }
  };

  useEffect(() => {
    if (counter.toString() === rest[1]) {
      setQuiz(null);
      setQuizFinished(true);
      scrollToRef(topRef);
    }
  }, [counter]);

  return (
    <div className="w-full min-h-screen">
      {loading ? (
        <div className="w-full min-h-96 flex justify-center items-center">
          <p>loading...</p>
        </div>
      ) : (
        <div
          ref={topRef}
          className="flex flex-wrap bg-slate-700 p-4 rounded-lg text-white"
        >
          <div className="md:w-1/2 text-center">
            {/* <p className="text-xl font-semibold">Subject : {rest[0]}</p> */}
            <p className="text-center text-2xl font-bold h-full flex items-center justify-center">
              Questions : {rest[1]}
            </p>
          </div>
          <div className="md:w-1/2">
            <p className="text-center text-2xl font-bold h-full flex items-center justify-center">
              Score : {score}
            </p>
          </div>
        </div>
      )}
      <div>
        {quiz ? (
          <div>
            {quiz.map((item: any) => {
              return (
                <div key={item.id}>
                  <QuizItem
                    {...item}
                    scorer={setScore}
                    counter={setCounter}
                    increment={rest[1] == "5" ? 6 : rest[1] == "10" ? 3 : 2}
                  />
                </div>
              );
            })}
          </div>
        ) : null}
      </div>
      {quizFinished ? (
        <div id="finished-quiz" className="mt-10">
          <div className="w-full flex justify-center">
            <Image
              className="rounded-xl border-2 border-black"
              height={400}
              src={doctorRenderer()}
              width={400}
            />
          </div>
          <p className="text-xl p-2 text-center font-extrabold">
            Quiz Finished !{message}
          </p>
          <div className="w-full p-4">
            <Button
              className="block mx-auto"
              color="primary"
              variant="shadow"
              onPress={() => router.back()}
            >
              Go Back
            </Button>
          </div>
        </div>
      ) : null}
    </div>
  );
};

export default Page;
