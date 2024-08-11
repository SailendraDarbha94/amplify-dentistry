"use client";
import { Card, CardBody, CardFooter, CardHeader } from "@nextui-org/card";
import { useParams, useRouter } from "next/navigation";
import { useContext, useState } from "react";
import { Image } from "@nextui-org/image";
import { Button } from "@nextui-org/button";
import { Divider } from "@nextui-org/divider";
import parse from "html-react-parser";
import {
  Modal,
  ModalBody,
  ModalContent,
  ModalFooter,
  ModalHeader,
  useDisclosure,
} from "@nextui-org/modal";
import { Input } from "@nextui-org/input";
import { GoogleGenerativeAI } from "@google/generative-ai";

import NoticeBoard from "@/components/noticeboard";
import { ToastContext } from "@/app/providers";
import { Select, SelectItem } from "@nextui-org/select";
import { yearWiseSubjects } from "@/app/lib/subjects";

const Page = () => {
  const [loading, setLoading] = useState<boolean>(false);
  const [query, setQuery] = useState<string>("");
  const [answer, setAnswer] = useState<string>("");
  const router = useRouter();

  const { isOpen, onOpen, onOpenChange, onClose } = useDisclosure();

  function formatContent(content: string) {
    // Replace headings (text between **) with <strong> and add a class for custom styling
    content = content.replace(
      /\*\*([^\*]+)\*\*/g,
      '<strong class="heading">$1</strong>'
    );

    // Replace bullet points (lines starting with *) with <li> elements
    content = content.replace(/\* ([^\*]+)/g, "<li>$1</li>");

    // Wrap lists in <ul> tags
    content = content.replace(/(<li>[\s\S]*?<\/li>)/g, "<ul>$1</ul>");

    // Remove any nested <ul> tags (in case of multiple replacements)
    content = content.replace(/<\/ul><ul>/g, "");

    return content;
  }

  const { toast } = useContext(ToastContext);

  const chatWithGemini = async () => {
    setLoading(true);
    try {
      const genAI = new GoogleGenerativeAI(
        process.env.NEXT_PUBLIC_GEMINI_KEY as string
      );
      const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });

      const finalPrompt = `You are a helpful assistant that helps Dental Students study for exams, any questions not pertaining to dentistry or medicine or the human body should be denied politely. Answer the question by the student now, question : ${query}`;
      // REGULAR
      // const result = await model.generateContent(prompt);
      // const response = await result.response;
      // const text = response.text();
      // console.log(text);
      // STREAM
      const result = await model.generateContentStream([finalPrompt]);

      if (result) {
        setLoading(false);
        setQuery("");
      }
      for await (const chunk of result.stream) {
        const chunkText = chunk.text();

        setAnswer((prev) => {
          let newText = prev + chunkText;
          const formattedContent = formatContent(newText);

          return formattedContent;
        });
      }
    } catch (err) {
      console.log(JSON.stringify(err));
      setLoading(false);
      toast({
        message: "An Error Occured! Please try again later",
        type: "error",
      });
    }
  };

  const [subject, setSelectedSubject] = useState<any | null>(null);
  const [number, setSelectedNumber] = useState<string | null>(null);
  const { year } = useParams();

  const handleSubjectChange = (e: any) => {
    setSelectedSubject(yearWiseSubjects(year as string)[e.currentKey]);
  };

  const handleNumberChange = (e: any) => {
    if (e.currentKey == 0) {
      setSelectedNumber("5");
    } else if (e.currentKey == 1) {
      setSelectedNumber("10");
    } else {
      setSelectedNumber("15");
    }
  };

  const routeToQuiz = () => {
    const subjectForRoute = subject.split(" ").join("").replace("&", "-");

    router.push(`/home/quiz/${subjectForRoute}/${number}`);
  };

  return (
    <div className="w-full min-h-screen">
      <Modal
        isOpen={isOpen}
        size="5xl"
        scrollBehavior="inside"
        onClose={() => setAnswer("")}
        onOpenChange={onOpenChange}
      >
        <ModalContent>
          {(onClose) => (
            <>
              <ModalHeader className="flex flex-col gap-1">
                Google Gemini
              </ModalHeader>
              <ModalBody>
                <Input
                  label="Enter your doubt"
                  type="text"
                  onChange={(e) => setQuery(e.target.value)}
                />
                <div className="p-2">
                  <p className="text-lg font-medium">{parse(answer)}</p>
                </div>
              </ModalBody>
              <ModalFooter>
                <Button color="danger" variant="light" onPress={onClose}>
                  Close
                </Button>
                <Button
                  className="ml-10"
                  color="primary"
                  onPress={chatWithGemini}
                >
                  Ask Gemini
                </Button>
              </ModalFooter>
            </>
          )}
        </ModalContent>
      </Modal>
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
              fill="none"
              viewBox="0 0 100 101"
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
      <div className="flex flex-wrap">
        <div className="w-full md:w-1/2 flex justify-center p-4">
          <Card isFooterBlurred className="border-none max-w-fit" radius="lg">
            <Image
              alt="generic question paper of a university exam"
              className="object-cover"
              height={200}
              src="/images/paperNew.png"
              width={200}
            />
            <CardFooter className="justify-between before:bg-white/10 border-white/20 border-1 overflow-hidden py-1 absolute before:rounded-xl rounded-large bottom-1 w-[calc(100%_-_8px)] shadow-small ml-1 z-10">
              <p className="text-tiny text-white">Question Paper Solver</p>
              <Button
                className="text-tiny text-white bg-black/20"
                color="default"
                radius="lg"
                size="sm"
                variant="flat"
                onPress={() => router.push("/home/qpaper")}
              >
                Try Now
              </Button>
            </CardFooter>
          </Card>
        </div>
        <div className="w-full md:w-1/2 p-4 text-white">
          <Card className="">
            <CardHeader className="flex gap-3">
              <Image
                alt="ai"
                className="dark:bg-white"
                height={40}
                radius="sm"
                src="/images/hugeicons--ai-network.png"
                width={40}
              />
              <div className="flex flex-col">
                <p className="text-md">Ask AI</p>
                <p className="text-small text-default-500">By Google Gemini</p>
              </div>
            </CardHeader>
            <Divider />
            <CardBody>
              <p>Solve any doubts regarding dentistry using AI</p>
            </CardBody>
            <Divider />
            <CardFooter>
              <Button
                className="block mx-auto"
                color="primary"
                variant="flat"
                onPress={onOpen}
              >
                Open Gemini
              </Button>
            </CardFooter>
          </Card>
        </div>
        <div className="w-full p-4 text-white">
          <Card className="w-full">
            <CardHeader className="flex gap-3">
              <Image
                alt="ai"
                className="dark:bg-white"
                height={40}
                radius="sm"
                src="/images/hugeicons--ai-network.png"
                width={40}
              />
              <div className="flex flex-col">
                <p className="text-md">Quiz Yourself</p>
                <p className="text-small text-default-500">By Google Gemini</p>
              </div>
            </CardHeader>
            <Divider />
            <CardBody>
              <p className="text-center text-lg font-semibold mb-4">
                Generate MCQs & Practice using AI
              </p>
              <div className="flex flex-wrap justify-evenly">
                <Select
                  className="max-w-xs"
                  label="Choose Subject"
                  onSelectionChange={handleSubjectChange}
                  //onSelect={handleChange}
                >
                  {yearWiseSubjects(year as string).map((sub, idx) => (
                    <SelectItem key={idx}>{sub}</SelectItem>
                  ))}
                </Select>
                <Select
                  onSelectionChange={handleNumberChange}
                  label="Number of Questions"
                  className="max-w-xs"
                >
                  {[5, 10, 15].map((sub, idx) => (
                    <SelectItem key={idx} className="text-center">
                      {JSON.stringify(sub)}
                    </SelectItem>
                  ))}
                </Select>
              </div>
            </CardBody>
            <Divider />
            <CardFooter>
              <Button
                className="block mx-auto"
                color={!subject || !number ? "danger" : "primary"}
                isDisabled={!subject || !number}
                variant="flat"
                onPress={routeToQuiz}
              >
                Create Quiz
              </Button>
            </CardFooter>
          </Card>
        </div>
        <div className="flex w-full justify-center my-4">
          <NoticeBoard />
        </div>
      </div>
    </div>
  );
};

export default Page;
