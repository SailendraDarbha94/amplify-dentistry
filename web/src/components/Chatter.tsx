"use client";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { useContext, useState } from "react";
import parse from "html-react-parser";
import { ToastContext } from "@/providers/ToastContextProvider";

const Chatter = () => {
  const [data, setData] = useState<string>("");
  const [prompt, setPrompt] = useState<string>("");
  const [loading, setLoading] = useState<boolean>(false);
  const { toast } = useContext(ToastContext);
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

  const chatWithGemini = async () => {
    setLoading(true);
    try {
      const genAI = new GoogleGenerativeAI(
        process.env.NEXT_PUBLIC_GEMINI_KEY as string
      );
      const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });

      const finalPrompt = `You are a helpful assistant that helps Dental Students study for exams, any questions not pertaining to dentistry or medicine or the human body should be denied politely. Answer the question by the student now, question : ${prompt}`;
      // REGULAR
      // const result = await model.generateContent(prompt);
      // const response = await result.response;
      // const text = response.text();
      // console.log(text);
      // STREAM
      const result = await model.generateContentStream([finalPrompt]);
      // print text as it comes in
      if (result) {
        setLoading(false);
        setPrompt("");
      }
      for await (const chunk of result.stream) {
        const chunkText = chunk.text();
        setData((prev) => {
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

  return (
    <div className="bg-purple-50 min-h-96 rounded-tr-xl rounded-tl-xl font-pMedium text-black mx-4">
      <h1 className="underline text-3xl text-center font-pBold p-2">Ask Your Doubts</h1>
      {loading ? (
        <div
          role="status"
          className="flex min-h-96 max-h-full justify-center items-center"
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
      ) : (
        <div className="mx-auto w-fit">
          <input
            type="text"
            className="focus:outline-none outline-dotted min-w-96 p-2 m-2 rounded-md inline-block text-primary"
            placeholder="enter your question"
            value={prompt}
            onChange={(e) => setPrompt(e.target.value)}
          />
          <button
            className="m-2 inline-block p-2 rounded-xl bg-primaryMore text-white"
            onClick={chatWithGemini}
          >
            Submit
          </button>
        </div>
      )}

      <div className="font-pMedium text-lg p-4">
        {data ? <div>{parse(data)}</div> : null}
      </div>
    </div>
  );
};

export default Chatter;
