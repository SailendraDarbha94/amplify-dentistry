"use client";
import { Card, CardBody, CardFooter, CardHeader } from "@nextui-org/card";
import { useEffect, useState } from "react";
import Image from "next/image";
import { child, get, getDatabase, ref, update } from "firebase/database";
import app from "@/config/firebase";
import { Button } from "@nextui-org/button";
import { useRouter } from "next/navigation";
import { subtitle } from "@/components/primitives";
import { GoogleGenerativeAI } from "@google/generative-ai";

interface ExamPaper {
  time_period: string;
  qpcode: string;
  long_essays: string[];
  short_essays: string[];
  short_answers: string[];
  university: string;
  subject?: string;
}
const Page = () => {
  const [selectedFile, setSelectedFile] = useState<any>(null);
  const [loading, setLoading] = useState<boolean>(false);
  const handleFileChange = (event: any) => {
    const file = event.target.files[0];
    setSelectedFile(file);
    //console.log(file);
  };
  async function fileToGenerativePart(file: File) {
    const base64EncodedDataPromise = new Promise((resolve) => {
      const reader: any = new FileReader();
      reader.onloadend = () => resolve(reader?.result?.split(",")[1]);
      reader.readAsDataURL(file);
    });
    return {
      inlineData: { data: await base64EncodedDataPromise, mimeType: file.type },
    };
  }
  const [papers, setPapers] = useState<ExamPaper[] | null>(null);
  const router = useRouter();

  function createAbbreviation(input: string): string {
    // Split the input string into an array of words
    const words = input.split(" ");

    // Extract the first letter of each word and join them together
    const abbreviation = words.map((word) => word[0].toLowerCase()).join("");

    return abbreviation;
  }

  function isExamPaper(response: any): response is ExamPaper {
    return (
      typeof response.time_period === "string" &&
      typeof response.qpcode === "string" &&
      Array.isArray(response.long_essays) &&
      response.long_essays.every((item: any) => typeof item === "string") &&
      Array.isArray(response.short_essays) &&
      response.short_essays.every((item: any) => typeof item === "string") &&
      Array.isArray(response.short_answers) &&
      response.short_answers.every((item: any) => typeof item === "string") &&
      (response.error_code === undefined ||
        typeof response.error_code === "string") &&
      (response.error_message === undefined ||
        typeof response.error_message === "string")
    );
  }

  const fetchQuestionPapers = async () => {
    try {
      console.log("entering");
      const db = getDatabase(app);
      const dbRef = ref(db);
      const data = await get(child(dbRef, "qpapers"));

      if (data.exists()) {
        const papers = await data.val();
        console.log(papers);
        setPapers(papers);
      }
    } catch (err) {
      console.log(JSON.stringify(err));
    }
  };

  async function solvePaper() {
    setLoading(true);
    const genAI = new GoogleGenerativeAI(
      process.env.NEXT_PUBLIC_GEMINI_KEY as string
    );
    const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });
    // Provide a text prompt to include with the image
    const prompt = `
    You are a dental professor in a reputed college and you help students analyse their question papers, you receive images and you analyse them,
    to find out whether they are a question paper of a univeristy or some other files.
    If it is a question paper then you shall analyse the paper and return back the questions with their respective categories which are 
    Long Essay, Short Essay & Short Answer, also mention the qp code of the paper and the month and year mentioned in the paper, along with the name of the university conducting the examination(exclude the location of the university) and the subject which is mentioned just above the q.p code in the image,
    return the data in triple quoted string containing JSON, here is a sample representation of that,  
    { university: Rajiv Gandhi University of Health Sciences, subject: Subject, time_period: Dec 2017, qpcode: 1123, long_essays: [questionone, questiontwo], short_essays: [questions...], short_answers: [string...]}
    If the provided image or file is not a question paper or is too blurred for analysis, then return an error inside triple quoted string with this JSON {
      error_message: "could not analyse the paper, please try again",
      error_code: 101
    }
    `;

    // const newPrompt = "describe this picture in a few lines";
    // Prepare image for input

    try {
      const imagePart: any = await fileToGenerativePart(selectedFile);
      const result: any = await model.generateContent([prompt, imagePart]);
      const response = result.response;
      const text: any = await response.text();
      console.log(text);

      //let parsedReponse: ExamPaper = JSON.parse(text);
      //let parsedReponse:any

      //console.log("parseddddd", parsedReponse, typeof parsedReponse);
      // if (parsedReponse?.error_code == "101") {
      //   console.log("Upload paper not stupid shit, you're testing my patience")
      // }

      // if (parsedReponse) {
      //   const db = getDatabase(app);
      //   const newKey = `${createAbbreviation(parsedReponse.university)}_${
      //     parsedReponse.qpcode
      //   }`;

      //   //const chekingRef = ref(db, `/qpapers/${newKey}`);

      //   get(child(ref(db), `/qpapers/${newKey}`)).then((snap) => {
      //     if (snap.exists()) {
      //       console.log("TODO : add toast, Paper already exists");
      //     } else {
      //       const updates: ExamPaper | any = {};
      //       updates["/qpapers/" + newKey] = parsedReponse;
      //       update(ref(db), updates);

      //       console.log("qpaper uploaded at /qpapers/" + newKey);
      //     }
      //   });

      //   //const newKey = push(child(ref(db), "qpapers")).key;

      //   //router.push(`/qpaper/${newKey}`);
      // } else {

      const newText = await text.split("json")[1];
      console.log(newText);
      const stringToParse = await newText.replace("```", "");
      console.log("string to parseeee", stringToParse);
      const newParser = JSON.parse(stringToParse);
      const db = getDatabase(app);

      if (isExamPaper(newParser)) {
        const newKey = `${createAbbreviation(newParser.university)}_${
          newParser.qpcode
        }`;

        //const chekingRef = ref(db, `/qpapers/${newKey}`);

        get(child(ref(db), `/qpapers/${newKey}`)).then((snap) => {
          if (snap.exists()) {
            console.log("TODO : add toast, Paper already exists");
          } else {
            const updates: ExamPaper | any = {};
            updates["/qpapers/" + newKey] = newParser;
            update(ref(db), updates);

            console.log("qpaper uploaded at /qpapers/" + newKey);
            router.push(`/home/qpaper/${newKey}`);
          }
        });

        setLoading(false);
      } else {
        console.log("bsdk paper upload kar");
      }
    } catch (err) {
      JSON.stringify(err);
      setLoading(false);
    }
    // for await (const chunk of result.stream) {
    //   const chunkText = chunk.text();
    //   console.log(chunkText);
    // }
  }

  useEffect(() => {
    fetchQuestionPapers();
  }, []);

  return (
    <div className="w-full min-h-screen">
      <div className="bg-purple-100 w-[90%] mx-auto rounded-full mb-10 p-5">
        <h1 className="text-lg font-semibold text-center p-2 mb-4">
          Upload Question paper to solve it using AI
        </h1>
        <div className="">
          <label htmlFor="test" className="block mx-auto text-md text-center">
            *Please select an Image file, other formats are currently
            unsupported
          </label>
          <input
            type="file"
            id="test"
            className="block p-2 mx-auto max-w-fit"
            onChange={handleFileChange}
          />
          {selectedFile ? (
            <Button
              disabled={loading}
              variant="solid"
              color="primary"
              className={`block mx-auto mt-4 ${
                loading ? "animate-pulse" : "animate-none"
              }`}
              onClick={solvePaper}
            >
              {loading ? "Loading..." : "Upload Paper"}
            </Button>
          ) : null}
        </div>
      </div>
      <h1 className="text-lg font-semibold text-center">Available Papers</h1>
      <br />
      {loading ? (
        <div className="w-full min-h-96 flex justify-center items-center">
          <div
            className="flex
                    min-h-96
                    max-h-full
                    justify-center
                    items-center"
            role="status"
          >
            <svg
              aria-hidden="true"
              className="w-8 h-8 text-gray-200 animate-spin dark:text-gray-600 fill-blue-600"
              viewBox="0 0 100 101"
              fill="none"
              xmlns="http://www.w3.org/2000/svg"
            >
              <path
                d="M100 50.5908C100 78.2051 77.6142 100.591 50 100.591C22.3858 100.591 0 78.2051 0 50.5908C0 22.9766 22.3858 0.59082 50 0.59082C77.6142 0.59082 100 22.9766 100 50.5908ZM9.08144 50.5908C9.08144 73.1895 27.4013 91.5094 50 91.5094C72.5987 91.5094 90.9186 73.1895 90.9186 50.5908C90.9186 27.9921 72.5987 9.67226 50 9.67226C27.4013 9.67226 9.08144 27.9921 9.08144 50.5908Z"
                fill="currentColor"
              />
              <path
                d="M93.9676 39.0409C96.393 38.4038 97.8624 35.9116 97.0079 33.5539C95.2932 28.8227 92.871 24.3692 89.8167 20.348C85.8452 15.1192 80.8826 10.7238 75.2124 7.41289C69.5422 4.10194 63.2754 1.94025 56.7698 1.05124C51.7666 0.367541 46.6976 0.446843 41.7345 1.27873C39.2613 1.69328 37.813 4.19778 38.4501 6.62326C39.0873 9.04874 41.5694 10.4717 44.0505 10.1071C47.8511 9.54855 51.7191 9.52689 55.5402 10.0491C60.8642 10.7766 65.9928 12.5457 70.6331 15.2552C75.2735 17.9648 79.3347 21.5619 82.5849 25.841C84.9175 28.9121 86.7997 32.2913 88.1811 35.8758C89.083 38.2158 91.5421 39.6781 93.9676 39.0409Z"
                fill="currentFill"
              />
            </svg>
            <span className="sr-only">Loading...</span>
          </div>
        </div>
      ) : null}
      <div className="">
        {papers ? (
          <div className="flex flex-wrap justify-evenly">
            {Object.keys(papers).map((paper: ExamPaper | any) => {
              return (
                <Card
                  className="py-4 max-w-fit block border-2 border-transparent dark:border-white"
                  key={paper.qpcode}
                >
                  <CardHeader className="pb-0 pt-2 px-4 flex-col items-start">
                    <p className="text-tiny uppercase font-bold">
                      {papers[paper].university}
                    </p>
                    <small className="text-default-500">
                      Q.P Code : {papers[paper].qpcode}
                    </small>
                    <h4 className="font-bold text-large">
                      {papers[paper].time_period}
                    </h4>
                    <h4 className="font-bold text-large">
                      {papers[paper].subject}
                    </h4>
                  </CardHeader>
                  <CardBody className="overflow-visible py-2">
                    <Image
                      alt="Card background"
                      className="object-cover rounded-xl mx-auto"
                      height={320}
                      src="/images/paperNew.png"
                      width={270}
                    />
                  </CardBody>
                  <CardFooter>
                    <Button
                      className="block mx-auto"
                      color="secondary"
                      variant="flat"
                      onPress={() => router.push(`/home/qpaper/${paper}`)}
                    >
                      View Paper
                    </Button>
                  </CardFooter>
                </Card>
              );
            })}
          </div>
        ) : null}
      </div>
    </div>
  );
};

export default Page;
