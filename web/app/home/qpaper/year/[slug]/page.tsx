"use client";
import { Card, CardBody, CardFooter, CardHeader } from "@nextui-org/card";
import { useContext, useEffect, useState } from "react";
import Image from "next/image";
import { child, get, getDatabase, ref, update } from "firebase/database";
import app from "@/config/firebase";
import { Button } from "@nextui-org/button";
import { useParams, useRouter } from "next/navigation";
import { subtitle } from "@/components/primitives";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { ToastContext } from "@/app/providers";
import {
  firstYearSubjects,
  fourthYearSubjects,
  secondYearSubjects,
  thirdYearSubjects,
} from "@/app/lib/subjects";

interface ExamPaper {
  time_period: string;
  qpcode: string;
  long_essays: string[];
  short_essays: string[];
  short_answers: string[];
  university: string;
  subject?: string;
  year_number?: string;
  url?: string;
}
const Page = () => {
  const [selectedFile, setSelectedFile] = useState<any>(null);
  const [loading, setLoading] = useState<boolean>(false);
  const handleFileChange = (event: any) => {
    const file = event.target.files[0];
    setSelectedFile(file);
    //console.log(file);
  };

  const { slug } = useParams();

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

  const { toast } = useContext(ToastContext);
  const fetchQuestionPapers = async () => {
    try {
      toast({
        message: "Fetching Available Question Papers!",
        type: "process",
      });
      //console.log("entering");
      const db = getDatabase(app);
      const dbRef = ref(db);
      const data = await get(child(dbRef, "qpapers"));

      if (data.exists()) {
        const papers: ExamPaper[] = await data.val();
        console.log(papers);

        const filteredPapers = Object.values(papers).filter(
          (p: ExamPaper) => p.year_number === slug,
        );

        let filteredPapersObj:any = {};

        Object.keys(papers).forEach((key:any) => {

          if (papers[key].year_number === slug) {
            filteredPapersObj[key] = papers[key];
            filteredPapersObj[key].url = key;
          }
        });

        //console.log(filteredPapers);

        toast({
          message: "Question Papers Fetched!",
          type: "success",
        });

        // setPapers(
        //   filteredPapers && filteredPapers.length > 0 ? filteredPapers : null
        // );
        setPapers(filteredPapersObj);
      }
    } catch (err) {
      console.log(JSON.stringify(err));
      toast({
        message: "An Error Occurred! Please try again later",
        type: "error",
      });
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
    Long Essay, Short Essay & Short Answer, also mention the qp code of the paper and the month and year mentioned in the paper, along with the name of the university conducting the examination(exclude the location of the university) and the subject name which is mentioned above the Q.P code which is a number containing usually 3 or four digits in the image, you shall also figure out the year number of students eligible for this examination paper which can have one of the four values which are "first" if the subject of the paper matches any value mentioned in the ${firstYearSubjects} array or "second" if the subject of the paper matches any value mentioned in the ${secondYearSubjects} array or "third" if the subject of the paper matches any value mentioned in the ${thirdYearSubjects} array or "fourth" if the subject of the paper matches any value mentioned in the ${fourthYearSubjects} array, you are smart enough to figure out the year number of eligible students even if the subject name mentioned on the paper does not exactly match any subject name in the array,
    also make sure that once you figure out the year number then you select that subject name from the array and use that instead of the full subject name from the paper,
    return the data in triple quoted string containing JSON, here is a sample representation of that,  
    { university: Rajiv Gandhi University of Health Sciences, subject: subject name, time_period: Dec 2017, year_number: first/second etc., qpcode: 1123, long_essays: [questionone, questiontwo], short_essays: [questions...], short_answers: [string...]}
    If the provided image or file is not a question paper or is too blurred for analysis, then return an error inside triple quoted string with this JSON {
      error_message: "could not analyse the paper, please try again",
      error_code: 101
    }
    `;

    try {
      const imagePart: any = await fileToGenerativePart(selectedFile);
      const result: any = await model.generateContent([prompt, imagePart]);
      const response = result.response;
      const text: any = await response.text();
      console.log(text);

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
            toast({
              message: "Paper Already Exists",
              type: "warning",
            });
            //console.log("TODO : add toast, Paper already exists");
          } else {
            const updates: ExamPaper | any = {};
            updates["/qpapers/" + newKey] = newParser;
            update(ref(db), updates);
            toast({
              message: "Paper Uploaded",
              type: "success",
            });
            console.log("qpaper uploaded at /qpapers/" + newKey);
            router.push(`/home/qpaper/${newKey}`);
          }
        });
        setLoading(false);
      } else {
        console.log(text);
        toast({
          message: "This is not a Valid Paper",
          type: "success",
        });
        setLoading(false);
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
    console.log(slug);
  }, []);

  return (
    <div className="w-full min-h-screen">
      <div className="bg-purple-300 dark:bg-purple-900 w-full md:w-[90%] mx-auto rounded-xl shadow-md shadow-slate-500 md:rounded-full mb-10 p-2 md:p-5">
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
      <h1 className="text-lg font-semibold text-center">
        {papers ? "Available Papers" : "No Uploaded Papers"}
      </h1>
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
            {Object.keys(papers).map((paper: ExamPaper | any, idx: number) => {
              return (
                <Card
                  className="py-4 my-2 max-w-fit block border-2 border-transparent dark:border-white"
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
                      onPress={() => router.push(`/home/qpaper/${papers[paper].url}`)}
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
