"use client";
import { ToastContext } from "@/app/providers";
import { subtitle, title } from "@/components/primitives";
import app from "@/config/firebase";
import { Accordion, AccordionItem } from "@nextui-org/accordion";
import { Button } from "@nextui-org/button";
import { Divider } from "@nextui-org/divider";
import { Tab, Tabs } from "@nextui-org/tabs";
import { getAuth, onAuthStateChanged } from "firebase/auth";
import { child, get, getDatabase, ref, remove } from "firebase/database";
import { useContext, useEffect, useState } from "react";
const Page = () => {
  const [loading, setLoading] = useState<boolean>(false);

  const [user, setUser] = useState<any | null>(null);
  const [answers, setAnswers] = useState<any | null>(null);
  const [flashCards, setFlashCards] = useState<any | null>(null);

  const { toast } = useContext(ToastContext);

  const fetchFlashCards = async (params: any) => {
    const db = getDatabase(app);

    try {
      get(child(ref(db), `/users/${params?.uid}/flashcards`)).then((snap) => {
        if (snap.exists()) {
          //console.log(snap);
          setFlashCards(snap.val());
        }
      });
    } catch (err) {
      console.log(JSON.stringify(err));
      toast({
        message: "An Error Occurred! Please try again later",
        type: "error",
      });
    }
  };

  const fetchAnswers = async (params: any) => {
    const db = getDatabase(app);
    //console.log(params?.uid);
    //console.log("entering db");

    get(child(ref(db), `/users/${params?.uid}/answers`)).then((snap) => {
      if (snap.exists()) {
        //console.log(snap);
        setAnswers(snap.val());
      }
    });
  };

  useEffect(() => {
    const auth = getAuth(app);

    onAuthStateChanged(auth, (u) => {
      //console.log("entering");
      if (u) {
        setUser(u);
        //console.log(u);
        fetchAnswers(u);
        fetchFlashCards(u);
      }
    });
  }, []);

  const deleteAnswer = async (params: string) => {
    setLoading(true);
    const db = getDatabase(app);
    const deletionRef = ref(db, `/users/${user.uid}/answers/${params}`);
    //console.log(params);

    await remove(deletionRef)
      .then(() => {
        toast({
          message: "Answer Deleted from Database",
          type: "sucess",
        });
        setLoading(false);
        setTimeout(() => {
          if (window) {
            window.location.reload();
          }
        }, 500);
      })
      .catch((err) => {
        console.log(JSON.stringify(err));
        toast({
          message: "An Error Occurred! Please try again later",
          type: "error",
        });
        setLoading(false);
      });
  };

  const deleteFlashCard = async (params: string) => {
    setLoading(true);
    const db = getDatabase(app);
    const deletionRef = ref(db, `/users/${user.uid}/flashcards/${params}`);
    //console.log(params);

    await remove(deletionRef)
      .then(() => {
        toast({
          message: "Flash Card Deleted from Database",
          type: "sucess",
        });
        setLoading(false);
        setTimeout(() => {
          if (window) {
            window.location.reload();
          }
        }, 500);
      })
      .catch((err) => {
        console.log(JSON.stringify(err));
        toast({
          message: "An Error Occurred! Please try again later",
          type: "error",
        });
        setLoading(false);
      });
  };

  return (
    <div className="w-full min-h-screen">
      {loading ? (
        <div className="w-full min-h-96 flex justify-center items-center">
          <div
            role="status"
            className="flex
                    min-h-96
                    max-h-full
                    justify-center
                    items-center"
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
        <h1 className={title()}>Your Profile</h1>
        {user ? (
          <div className="p-2 text-xl font-bold underline">{user?.email}</div>
        ) : null}
      </div>
      <br />
      <br />
      <Tabs aria-label="Options" size="md" radius="lg" className="block">
        <Tab key="Answers" title="Answers">
          <h2 className="text-lg font-semibold text-center">Saved Answers</h2>{" "}
          <div>
            {answers ? (
              <Accordion selectionMode="single">
                {Object.keys(answers).map((ans: any, idx: number) => {
                  return (
                    <AccordionItem
                      key={idx}
                      aria-label={answers[ans].question}
                      title={answers[ans].question}
                    >
                      <div className="text-medium font-light tracking-wide">
                        {answers[ans].answer ? (
                          <div className="px-4 pb-4 text-md tracking-wide font-pLight ">
                            {answers[ans].answer.map(
                              (segment: any, index: number) => {
                                if (typeof segment === "string") {
                                  return (
                                    <p
                                      key={index}
                                      className="font-pLight text-md"
                                    >
                                      {segment}
                                    </p>
                                  );
                                } else if (segment.type === "bold") {
                                  return (
                                    <div key={index} className="mt-2">
                                      <h1 className="text-lg font-pMedium">
                                        {segment.content}
                                      </h1>
                                    </div>
                                  );
                                }

                                return null;
                              }
                            )}
                          </div>
                        ) : null}
                      </div>
                      <Button
                        className="block mx-auto my-4 p-2"
                        color="danger"
                        radius="md"
                        variant="ghost"
                        onPress={() => deleteAnswer(ans)}
                      >
                        Delete
                      </Button>
                    </AccordionItem>
                  );
                })}
              </Accordion>
            ) : null}
          </div>
        </Tab>
        <Tab key="Flash Cards" title="Flash Cards">
          <h2 className="text-lg font-semibold text-center">Flash Cards</h2>
        </Tab>
      </Tabs>

      {/* <div>{JSON.stringify(user)}</div> */}

      <div>
        {flashCards ? (
          <Accordion selectionMode="single">
            {Object.keys(flashCards).map((flash: any, idx: number) => {
              return (
                <AccordionItem
                  key={idx}
                  aria-label={flashCards[flash].question}
                  title={flashCards[flash].question}
                >
                  <div className="text-medium font-light tracking-wide">
                    {flashCards[flash].answer}
                  </div>
                  <Button
                    className="block mx-auto my-4 p-2"
                    color="danger"
                    radius="md"
                    variant="ghost"
                    onPress={() => deleteFlashCard(flash)}
                  >
                    Delete
                  </Button>
                </AccordionItem>
              );
            })}
          </Accordion>
        ) : null}
      </div>
    </div>
  );
};

export default Page;
