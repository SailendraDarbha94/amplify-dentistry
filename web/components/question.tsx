"use client";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { useContext, useEffect, useState } from "react";
import { child, getDatabase, push, ref, update } from "firebase/database";
import { getAuth, onAuthStateChanged } from "firebase/auth";

import app from "@/config/firebase";
import { ToastContext } from "@/app/providers";

interface ProviderData {
  providerId: string;
  uid: string;
  displayName: string | null;
  email: string;
  phoneNumber: string | null;
  photoURL: string | null;
}

interface StsTokenManager {
  refreshToken: string;
  accessToken: string;
  expirationTime: number;
}

interface User {
  uid: string;
  email: string;
  emailVerified: boolean;
  isAnonymous: boolean;
  providerData: ProviderData[];
  stsTokenManager: StsTokenManager;
  createdAt: string;
  lastLoginAt: string;
  apiKey: string;
  appName: string;
}

interface ParsedSegment {
  type: "bold";
  content: string;
}

const QuestionItem = ({
  question,
  type,
}: {
  question: string;
  type: string;
}) => {
  const [loading, setLoading] = useState<boolean>(false);
  const [disabled, setDisabled] = useState<boolean>(false);
  const [answer, setAnswer] = useState<ParsedSegment[] | null>(null);
  //const [wholeAnswer, setWholeAnswer] = useState<any | null>(null);
  const { toast } = useContext(ToastContext);

  function parseText(
    text: string
  ): Array<string | { type: "bold"; content: string }> {
    const regex = /\*\*(.*?)\*\*/g;
    const segments: Array<string | { type: "bold"; content: string }> = [];
    let lastIndex = 0;

    let match;

    while ((match = regex.exec(text)) !== null) {
      // Add the text before the ** marker
      if (match.index > lastIndex) {
        let plainText = text.slice(lastIndex, match.index);

        // Remove any single * symbols
        plainText = plainText.replace(/\*/g, "");
        segments.push(plainText);
      }
      // Add the bold text
      segments.push({ type: "bold", content: match[1] });
      lastIndex = regex.lastIndex;
    }

    // Add any remaining text after the last ** marker
    if (lastIndex < text.length) {
      let remainingText = text.slice(lastIndex);

      // Remove any single * symbols
      remainingText = remainingText.replace(/\*/g, "");
      segments.push(remainingText);
    }

    return segments;
  }

  const questionAnswerer = async () => {
    setLoading(true);
    try {
      const genAI = new GoogleGenerativeAI(
        process.env.NEXT_PUBLIC_GEMINI_KEY as string
      );
      const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });
      const prompt = `You are an assistant professor at a University of Dental Sciences, you are very knowledgeable but you only answer things that are pertaining to dentistry, at the level of a grad student in your univeristy and also based on the type of question(long essays contain approximately 500 words, short essays contain approximately 250 words and short answers contain about a 100 words), also keep in mind that when provided abbreviations as questions you have to just give a small explanation of about it and tell how it relates to dentistry, now answer this question of type ${type}, ${question}`;
      const result: any = await model.generateContent(prompt);
      const text = await result.response.text();

      const segments: string[] | any = parseText(text);

      //setWholeAnswer(text);
      setAnswer(segments);
      //   for await (const chunk of result.stream) {
      //     const chunkText = chunk.text();
      //     console.log(chunkText);
      //     setAnswer((prev: string) => {
      //       return prev + chunkText;
      //     });
      //   }
      toast({
        message: "Answer Generated!",
        type: "success",
      });
      setLoading(false);
    } catch (err) {
      toast({
        message: "An Error Occurred! Please Try Again Later",
        type: "error",
      });
      console.log(JSON.stringify(err));
    }
  };

  const [user, setUser] = useState<User | null>(null);

  useEffect(() => {
    const auth = getAuth(app);

    onAuthStateChanged(auth, (user: User | any) => setUser(user));
  }, [user]);

  const answerSaver = async () => {
    setLoading(true);
    const db = getDatabase(app);
    const newKey = push(child(ref(db), `/users/${user?.uid}/answers`)).key;

    try {
      const updates: any | null = {};

      updates[`/users/${user?.uid}/answers/${newKey}`] = {
        question: question,
        type: type,
        answer: answer,
      };
      console.log(updates);
      await update(ref(db), updates);
      console.log("answer saved");
      toast({
        message: "Answer Saved to Profile!",
        type: "success",
      });
      setDisabled(true);
      setLoading(false);
    } catch (err) {
      setLoading(false);
      toast({
        message: "An Error Occurred! Please Try Again Later",
        type: "error",
      });
      console.log(JSON.stringify(err));
    }
  };

  return (
    <div className="mb-2 inline">
      <h1 className="text-md font-pMedium inline mr-4">{question}</h1>
      {answer ? (
        <button
          disabled={disabled}
          className={`text-sm inline ${
            loading ? "animate-pulse" : "animate-none"
          } ${disabled ? "bg-slate-600" : "bg-black"} dark:bg-white text-white dark:text-black rounded-md py-1 px-2`}
          onClick={answerSaver}
        >
          {loading ? "Loading" : disabled ? "Saved" : "Save"}
        </button>
      ) : (
        <button
          className={`text-sm inline ${
            loading ? "animate-pulse" : "animate-none"
          } bg-black text-white dark:bg-white dark:text-black rounded-md py-1 px-2`}
          disabled={loading}
          onClick={questionAnswerer}
        >
          {loading ? "Loading" : "Solve"}
        </button>
      )}
      {answer ? (
        <div className="px-4 pb-4 text-md tracking-wide font-pLight ">
          {answer.map((segment, index) => {
            if (typeof segment === "string") {
              return (
                <p key={index} className="font-pLight text-md">
                  {segment}
                </p>
              );
            } else if (segment.type === "bold") {
              return (
                <div key={index} className="mt-2">
                  <h1 className="text-lg font-pMedium">{segment.content}</h1>
                </div>
              );
            }

            return null;
          })}
        </div>
      ) : null}
    </div>
  );
};

export default QuestionItem;
