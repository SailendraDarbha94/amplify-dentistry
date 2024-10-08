"use client";
import { Button } from "@nextui-org/button";
import { Card, CardHeader, CardBody, CardFooter } from "@nextui-org/card";
import { Divider } from "@nextui-org/divider";
import { useContext, useState } from "react";

import { ToastContext } from "@/app/providers";
import {
  Modal,
  ModalBody,
  ModalContent,
  ModalFooter,
  ModalHeader,
  useDisclosure,
} from "@nextui-org/modal";
import { child, getDatabase, push, ref, update } from "firebase/database";
import app from "@/config/firebase";
import { getAuth, onAuthStateChanged } from "firebase/auth";
const QuizItem = ({
  id,
  question,
  answer,
  options,
  scorer,
  counter,
  setCounter,
  increment,
}: {
  id: number;
  question: string;
  answer: string;
  options: string[];
  scorer: any;
  counter: any;
  setCounter: any;
  increment: number;
}) => {
  const [loading, setLoading] = useState<boolean>(false);
  const [optionsDisabled, setOptionsDisabled] = useState<boolean>(false);
  const [flashCardSaved, setFlashCardSaved] = useState<boolean>(false);
  const { toast } = useContext(ToastContext);
  const { isOpen, onOpen, onOpenChange } = useDisclosure();

  const createFlashCard = async () => {
    setLoading(true);
    const db = getDatabase(app);
    const auth = getAuth(app);

    onAuthStateChanged(auth, (user) => {
      const newKey = push(child(ref(db), `/users/${user?.uid}/flashcards`)).key;
      const updates: any | null = {};

      updates[`/users/${user?.uid}/flashcards/${newKey}`] = {
        question: question,
        answer: answer,
      };

      update(ref(db), updates)
        .then(() => {
          console.log("flashcard saved");
          setLoading(false);
          setFlashCardSaved(true);
          toast({
            message: "Flashcard Saved to Profile!",
            type: "success",
          });
        })
        .catch((err) => {
          console.log(JSON.stringify(err));
          setLoading(false);
          toast({
            message: "An Error Occurred! Please Try Again Later",
            type: "error",
          });
        });
    });

    setLoading(false);
  };

  const checkAnswer = async (params: string) => {
    if (params == answer) {
      setOptionsDisabled(true);
      scorer((prev: number) => {
        return prev + increment;
      });
      toast({
        message: "Correct Answer",
        type: "success",
      });
    } else {
      setOptionsDisabled(true);
      toast({
        message: "Wrong Answer",
        type: "error",
      });
    }
  };

  const nextQuestion = async () => {
    await setTimeout(() => {
      setCounter((prev: number) => {
        return prev + 1;
      });
    }, 300);
  };

  return (
    <div className="w-full min-h-fit">
      <Modal size="3xl" isOpen={isOpen} onOpenChange={onOpenChange}>
        <ModalContent>
          {(onClose) => (
            <>
              <ModalHeader className="flex flex-col gap-1">
                <h1 className="text-2xl font-extrabold text-center">
                  Flash Card
                </h1>
              </ModalHeader>
              <ModalBody>
                <div className="mt-4">
                  <h1 className="text-lg font-light">{question}</h1>
                  <br />
                  <p className="text-lg font-semibold">{answer}</p>
                </div>
              </ModalBody>
              <ModalFooter>
                <Button color="danger" variant="light" onPress={onClose}>
                  Close
                </Button>
                <Button
                  isDisabled={flashCardSaved}
                  color="primary"
                  onPress={() => {
                    onClose(), createFlashCard();
                  }}
                >
                  {flashCardSaved ? "Saved" : "Save"}
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
      <div className="my-4 p-2">
        <Card className="w-full">
          <CardHeader className="flex gap-3">
            <p className="text-lg">
              {`Question number ${counter} : ${question}`}
            </p>
            {optionsDisabled ? (
              <Button
                className="ml-auto min-w-24 max-w-24"
                color="warning"
                onPress={onOpen}
                radius="full"
                size="sm"
                variant="shadow"
              >
                <span className="font-bold text-gray-900">FLASH CARD</span>
              </Button>
            ) : null}
          </CardHeader>
          <Divider />
          <CardBody className="">
            <div className="flex flex-wrap justify-between w-full">
              {options.map((option, idx) => {
                return (
                  <Button
                    key={idx}
                    className="w-[45%] my-2 block text-wrap min-h-fit"
                    color={
                      optionsDisabled && option == answer
                        ? "success"
                        : "secondary"
                    }
                    isDisabled={optionsDisabled}
                    radius="full"
                    variant={
                      optionsDisabled && option == answer ? "solid" : "ghost"
                    }
                    onPress={() => checkAnswer(option)}
                  >
                    {option}
                  </Button>
                );
              })}
            </div>
          </CardBody>
          <CardFooter className="flex justify-center">
            <Button
              isDisabled={!optionsDisabled}
              color={optionsDisabled ? "secondary" : "danger"}
              radius="full"
              variant={optionsDisabled ? "solid" : "flat"}
              onPress={nextQuestion}
            >
              Next Question
            </Button>
          </CardFooter>
        </Card>
      </div>
    </div>
  );
};

export default QuizItem;
