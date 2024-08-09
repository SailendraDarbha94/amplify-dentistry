"use client";
import { Link } from "@nextui-org/link";
import { button as buttonStyles } from "@nextui-org/theme";
import {
  Modal,
  ModalContent,
  ModalHeader,
  ModalBody,
  ModalFooter,
  useDisclosure,
} from "@nextui-org/modal";
import { Button } from "@nextui-org/button";
import { Input } from "@nextui-org/input";
import { useState } from "react";
import {
  browserLocalPersistence,
  getAuth,
  setPersistence,
  signInWithEmailAndPassword,
} from "firebase/auth";

import { title } from "@/components/primitives";
import { siteConfig } from "@/config/site";
import app from "@/config/firebase";
import { useRouter } from "next/navigation";

export default function Home() {
  const { isOpen, onOpen, onOpenChange } = useDisclosure();
  const router = useRouter();
  const [email, setEmail] = useState<string>("");
  const [password, setPassword] = useState<string>("");
  const [loading, setLoading] = useState<boolean>(false);

  const auth = getAuth(app);
  const loginUser = async () => {
    setLoading(true);
    try {
      setPersistence(auth, browserLocalPersistence).then(() => {
        signInWithEmailAndPassword(auth, email, password).then((cb) => {
          console.log(cb);
          if (cb.user) {
            // TODO ADD TOAST
            // toast({
            //   message: "User Logged In, Redirecting",
            //   type: "success",
            // });
            setTimeout(() => {
              router.push("/home");
            }, 1500);
            setLoading(false);
          }
        });
      });
    } catch (err) {
      // toast({
      //   message: "An Error Occured! Please try again later",
      //   type: "error",
      // });
      setLoading(false);
      console.log("Error Occured", err);
    }
  };

  return (
    <section className="flex flex-col items-center justify-center gap-4 py-8 md:py-10">
      <Modal isOpen={isOpen} onOpenChange={onOpenChange}>
        <ModalContent>
          {(onClose) => (
            <>
              <ModalHeader className="flex flex-col gap-1">
                Sign In To Your Account
              </ModalHeader>
              <ModalBody>
                <Input
                  label="Email"
                  type="email"
                  onChange={(e) => setEmail(e.target.value)}
                />
                <Input
                  label="Password"
                  type="password"
                  onChange={(e) => setPassword(e.target.value)}
                />
              </ModalBody>
              <ModalFooter>
                <Button color="danger" variant="light" onPress={onClose}>
                  Close
                </Button>
                <Button color="primary" onPress={loginUser}>
                  Login
                </Button>
              </ModalFooter>
            </>
          )}
        </ModalContent>
      </Modal>
      <div className="inline-block max-w-lg text-center justify-center">
        <h1 className={title({ color: "cyan" })}>Amplify&nbsp;</h1>
        <h1 className={title({ color: "green" })}>Dentistry&nbsp;</h1>
        <br />
        <br />
        {/* <h1 className={title({ color: "pink" })}>
          Platform for Dental Students
        </h1> */}
        <p className="max-w-2xl mb-6 font-light text-gray-500 lg:mb-8 md:text-lg lg:text-xl dark:text-gray-400">
          Whether you&apos;re a student or a professional, you can find
          something worthwhile here
        </p>
      </div>

      <div className="flex gap-3">
        <Link
          //isExternal
          className={buttonStyles({
            variant: "bordered",
            radius: "full",
            color: "primary",
          })}
          href={siteConfig.internalLinks.signUp}
        >
          Sign Up
          {/* <ToothBrushIcon /> */}
        </Link>
        <Button color="primary" radius="full" variant="shadow" onPress={onOpen}>
          Login
        </Button>
      </div>
      <main className="flex min-h-screen tracking-wider flex-col items-center justify-between p-4 md:p-14 lg:p-24">
        <section className="bg-white rounded-lg dark:bg-gray-900 mb-10">
          {/* <div className="grid max-w-screen-xl px-4 py-8 mx-auto lg:gap-8 xl:gap-0 lg:py-16 lg:grid-cols-12">
            <div className="mr-auto place-self-center lg:col-span-7">
              <h1 className="max-w-2xl font-pBold mb-4 text-4xl font-extrabold tracking-tight leading-none md:text-5xl xl:text-6xl dark:text-white">
                Amplify Your Dental Knowledge
              </h1>
              <p className="max-w-2xl mb-6 font-pMedium font-light text-gray-500 lg:mb-8 md:text-lg lg:text-xl dark:text-gray-400">
                Whether you&apos;re a student or a professional, you can find
                something worthwhile here
              </p>
              <a
                href="#feature-section"
                className="inline-flex items-center justify-center px-5 py-3 mr-3 text-base font-medium text-center rounded-lg bg-primary-700 hover:bg-primary-800 focus:ring-4 focus:ring-primary-300 dark:focus:ring-primary-900"
              >
                Know More
                <svg
                  className="w-5 h-5 ml-2 -mr-1"
                  fill="currentColor"
                  viewBox="0 0 20 20"
                  xmlns="http://www.w3.org/2000/svg"
                >
                  <path
                    fillRule="evenodd"
                    d="M10.293 3.293a1 1 0 011.414 0l6 6a1 1 0 010 1.414l-6 6a1 1 0 01-1.414-1.414L14.586 11H3a1 1 0 110-2h11.586l-4.293-4.293a1 1 0 010-1.414z"
                    clipRule="evenodd"
                  ></path>
                </svg>
              </a>
              <a
                href="/auth/login"
                className="inline-flex items-center justify-center px-5 py-3 text-base font-medium text-center text-gray-900 border border-gray-300 rounded-lg hover:bg-gray-100 focus:ring-4 focus:ring-gray-100 dark:text-white dark:border-gray-700 dark:hover:bg-gray-700 dark:focus:ring-gray-800"
              >
                Login
              </a>
            </div>
            <div className="hidden lg:mt-0 lg:col-span-5 lg:flex">
              <img src="/ampdent-logo-image.png" alt="logo" className="" />
            </div>
          </div> */}
        </section>
        <section className="bg-white dark:bg-gray-900 rounded-lg mb-10">
          <div className="gap-16 max-w-screen-xl items-center py-8 px-4 mx-auto lg:grid lg:grid-cols-2 lg:py-16 lg:px-6">
            <div className="font-light text-gray-500 sm:text-lg dark:text-gray-400">
              <h2 className="mb-4 font-bold text-4xl tracking-tight text-gray-900 dark:text-white">
                Powered by AI
              </h2>
              <p className="mb-4 font-light">
                Whether you have doubts that need to be resolved or you just
                want to plan your studies, our helpful AI enabled features will
                assist you every step of the way.
              </p>
              <p className="font-light">
                You can also use the AI to practice your knowledge and generate
                endless quizzes, make flashcards to help you revise important
                concepts before your tests and so much more...
              </p>
            </div>
            <div className="grid grid-cols-2 gap-4 mt-8">
              <img
                alt="office content 2"
                className="mt-4 w-full lg:mt-10 rounded-lg"
                src="/images/amplify-white-bg.jpg"
              />
              <img
                alt="office content 1"
                className="w-full rounded-lg"
                src="/images/paperNew.png"
              />
            </div>
          </div>
        </section>
        <section
          className="bg-white dark:bg-gray-900 rounded-lg mb-10"
          id="feature-section"
        >
          <div className="py-8 px-4 mx-auto max-w-screen-xl sm:py-16 lg:px-6">
            <div className="max-w-screen-md mb-8 lg:mb-16">
              <h2 className="mb-4 text-4xl tracking-tight font-bold text-gray-900 dark:text-white">
                Designed to empower Students
              </h2>
              <p className="text-gray-500 font-light tracking-wide sm:text-lg dark:text-gray-400">
                Here at AmplifyDentistry you can gain important knowledge that
                will help you throughout your life but in a way that is less
                intimidating and more fun than the traditional college
              </p>
            </div>
            <div className="space-y-8 md:grid md:grid-cols-2 lg:grid-cols-3 md:gap-12 md:space-y-0">
              <div>
                <div className="flex justify-center items-center mb-4 w-10 h-10 rounded-full bg-primary-100 lg:h-12 lg:w-12 dark:bg-primary-900">
                  <svg
                    className="w-5 h-5 lg:w-6 lg:h-6"
                    viewBox="0 0 1696 1536"
                    xmlns="http://www.w3.org/2000/svg"
                  >
                    <path
                      d="M1671 350q40 57 18 129l-275 906q-19 64-76.5 107.5T1215 1536H292q-77 0-148.5-53.5T44 1351q-24-67-2-127q0-4 3-27t4-37q1-8-3-21.5t-3-19.5q2-11 8-21t16.5-23.5T84 1051q23-38 45-91.5t30-91.5q3-10 .5-30t-.5-28q3-11 17-28t17-23q21-36 42-92t25-90q1-9-2.5-32t.5-28q4-13 22-30.5t22-22.5q19-26 42.5-84.5T372 283q1-8-3-25.5t-2-26.5q2-8 9-18t18-23t17-21q8-12 16.5-30.5t15-35t16-36t19.5-32T504.5 12t36-11.5T588 6l-1 3q38-9 51-9h761q74 0 114 56t18 130l-274 906q-36 119-71.5 153.5T1057 1280H188q-27 0-38 15q-11 16-1 43q24 70 144 70h923q29 0 56-15.5t35-41.5l300-987q7-22 5-57q38 15 59 43m-1064 2q-4 13 2 22.5t20 9.5h608q13 0 25.5-9.5T1279 352l21-64q4-13-2-22.5t-20-9.5H670q-13 0-25.5 9.5T628 288zm-83 256q-4 13 2 22.5t20 9.5h608q13 0 25.5-9.5T1196 608l21-64q4-13-2-22.5t-20-9.5H587q-13 0-25.5 9.5T545 544z"
                      fill="currentColor"
                    />
                  </svg>
                </div>
                <h3 className="mb-2 text-xl font-bold dark:text-white">
                  Theory
                </h3>
                <p className="text-gray-500 font-light dark:text-gray-400">
                  There is a wealth of theoretical knowledge curated from
                  excellent learning resources at your fingertips.
                </p>
              </div>
              <div>
                <div className="flex justify-center items-center mb-4 w-10 h-10 rounded-full bg-primary-100 lg:h-12 lg:w-12 dark:bg-primary-900">
                  <svg
                    className="h-5 w-5 lg:w-6 lg:h-6"
                    viewBox="0 0 24 24"
                    xmlns="http://www.w3.org/2000/svg"
                  >
                    <path
                      d="M17 20H4V7c0-.55-.45-1-1-1s-1 .45-1 1v13c0 1.1.9 2 2 2h13c.55 0 1-.45 1-1s-.45-1-1-1"
                      fill="currentColor"
                    />
                    <path
                      d="M20 2H8c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2m-5.99 13c-.59 0-1.05-.47-1.05-1.05c0-.59.47-1.04 1.05-1.04c.59 0 1.04.45 1.04 1.04c-.01.58-.45 1.05-1.04 1.05m2.5-6.17c-.63.93-1.23 1.21-1.56 1.81c-.08.14-.13.26-.16.49c-.05.39-.36.68-.75.68h-.03c-.44 0-.79-.38-.75-.82c.03-.28.09-.57.25-.84c.41-.73 1.18-1.16 1.63-1.8c.48-.68.21-1.94-1.14-1.94c-.61 0-1.01.32-1.26.7c-.19.29-.57.39-.89.25c-.42-.18-.6-.7-.34-1.07c.51-.74 1.36-1.29 2.48-1.29c1.23 0 2.08.56 2.51 1.26c.37.61.58 1.73.01 2.57"
                      fill="currentColor"
                    />
                  </svg>
                </div>
                <h3 className="mb-2 text-xl font-bold dark:text-white">MCQs</h3>
                <p className="text-gray-500 font-light dark:text-gray-400">
                  We use AI to generate MCQs which means that you can practice
                  new quizzes everyday and not get bored.
                </p>
              </div>
              <div>
                <div className="flex justify-center items-center mb-4 w-10 h-10 rounded-full bg-primary-100 lg:h-12 lg:w-12 dark:bg-primary-900">
                  <svg
                    className="w-5 h-5 lg:w-6 lg:h-6"
                    viewBox="0 0 14 14"
                    xmlns="http://www.w3.org/2000/svg"
                  >
                    <path
                      clipRule="evenodd"
                      d="M0 1.5A1.5 1.5 0 0 1 1.5 0h11A1.5 1.5 0 0 1 14 1.5v1.375H0zm0 2.625h14V9.5a1.5 1.5 0 0 1-1.5 1.5h-2.19l1.72 1.72a.75.75 0 1 1-1.06 1.06L8.19 11h-.44v2.25a.75.75 0 0 1-1.5 0V11h-.44l-2.78 2.78a.75.75 0 0 1-1.06-1.06L3.69 11H1.5A1.5 1.5 0 0 1 0 9.5z"
                      fill="currentColor"
                      fillRule="evenodd"
                    />
                  </svg>
                </div>
                <h3 className="mb-2 text-xl font-bold dark:text-white">
                  Noticeboard
                </h3>
                <p className="text-gray-500 dark:text-gray-400 font-light">
                  Stay upto date on important and relevant news related to the
                  dental world at a glance cause you&apos;ll get it at a single
                  place.
                </p>
              </div>
              <div>
                <div className="flex justify-center items-center mb-4 w-10 h-10 rounded-full bg-primary-100 lg:h-12 lg:w-12 dark:bg-primary-900">
                  <svg
                    className="h-5 w-5 lg:w-6 lg:h-6"
                    viewBox="0 0 24 24"
                    xmlns="http://www.w3.org/2000/svg"
                  >
                    <path
                      d="M14 4h-4C6.229 4 4.343 4 3.172 5.172c-.844.843-1.08 2.057-1.146 4.078h19.948c-.066-2.021-.302-3.235-1.146-4.078C19.657 4 17.771 4 14 4"
                      fill="currentColor"
                    />
                    <path
                      clipRule="evenodd"
                      d="M14 20h-4c-3.771 0-5.657 0-6.828-1.172C2 17.657 2 15.771 2 12c0-.442 0-.858.002-1.25h19.996c.002.392.002.808.002 1.25c0 3.771 0 5.657-1.172 6.828C19.657 20 17.771 20 14 20m2.045-7.75c.433 0 .83 0 1.152.043c.356.048.731.16 1.04.47c.31.309.422.684.47 1.04c.043.323.043.72.043 1.152v.09c0 .433 0 .83-.043 1.152c-.048.356-.16.731-.47 1.04c-.309.31-.684.422-1.04.47c-.323.043-.72.043-1.152.043h-.09c-.433 0-.83 0-1.152-.043c-.356-.048-.731-.16-1.04-.47c-.31-.309-.422-.684-.47-1.04c-.043-.323-.043-.72-.043-1.152v-.09c0-.433 0-.83.043-1.152c.048-.356.16-.731.47-1.04c.309-.31.684-.422 1.04-.47c.323-.043.72-.043 1.152-.043zM5.25 13.5a.75.75 0 0 1 .75-.75h2a.75.75 0 0 1 0 1.5H6a.75.75 0 0 1-.75-.75m0 3a.75.75 0 0 1 .75-.75h4a.75.75 0 0 1 0 1.5H6a.75.75 0 0 1-.75-.75"
                      fill="currentColor"
                      fillRule="evenodd"
                    />
                    <path
                      d="m14.823 13.823l.003-.001a.702.702 0 0 1 .177-.042c.21-.028.504-.03.997-.03s.787.002.997.03a.702.702 0 0 1 .177.042l.003.001l.001.003a.702.702 0 0 1 .042.177c.028.21.03.504.03.997s-.002.787-.03.997a.702.702 0 0 1-.042.177l-.001.003l-.003.001a.702.702 0 0 1-.177.042c-.21.028-.504.03-.997.03s-.787-.002-.997-.03a.702.702 0 0 1-.177-.042l-.003-.001l-.001-.003a.702.702 0 0 1-.042-.177c-.028-.21-.03-.504-.03-.997s.002-.787.03-.997a.702.702 0 0 1 .042-.177z"
                      fill="currentColor"
                    />
                  </svg>
                </div>
                <h3 className="mb-2 text-xl font-bold dark:text-white">
                  Flash Cards
                </h3>
                <p className="text-gray-500 dark:text-gray-400 font-light">
                  No longer shall you need to worry about forgetting key details
                  about important topics, we&apos;ve got you covered.
                </p>
              </div>
              <div>
                <div className="flex justify-center items-center mb-4 w-10 h-10 rounded-full bg-primary-100 lg:h-12 lg:w-12 dark:bg-primary-900">
                  <svg
                    className="w-5 h-5 lg:w-6 lg:h-6"
                    viewBox="0 0 24 24"
                    xmlns="http://www.w3.org/2000/svg"
                  >
                    <path
                      d="M7 18q-.425 0-.712-.288T6 17v-2h13V6h2q.425 0 .713.288T22 7v12.575q0 .675-.612.938T20.3 20.3L18 18zm-1-5l-2.3 2.3q-.475.475-1.088.213T2 14.575V3q0-.425.288-.712T3 2h13q.425 0 .713.288T17 3v9q0 .425-.288.713T16 13z"
                      fill="currentColor"
                    />
                  </svg>
                </div>
                <h3 className="mb-2 text-xl font-bold dark:text-white">
                  Forums
                </h3>
                <p className="text-gray-500 dark:text-gray-400 font-light">
                  For when you need the support or guidance of the Dental
                  community, they&apos;re around for you.
                </p>
              </div>
              <div>
                <div className="flex justify-center items-center mb-4 w-10 h-10 rounded-full bg-primary-100 lg:h-12 lg:w-12 dark:bg-primary-900">
                  <svg
                    className="w-5 h-5 lg:w-6 lg:h-6"
                    viewBox="0 0 24 24"
                    xmlns="http://www.w3.org/2000/svg"
                  >
                    <path
                      d="M10 16v4h4v-4zm-2-2v-4H4v4zm2 0h4v-4h-4zm6 0h4v-4h-4zm0-6h4V4h-4zm-8 8H4q-.825 0-1.412-.587T2 14v-4q0-.825.588-1.412T4 8h10V4q0-.825.588-1.412T16 2h4q.825 0 1.413.588T22 4v10q0 .825-.587 1.413T20 16h-4v4q0 .825-.587 1.413T14 22h-4q-.825 0-1.412-.587T8 20z"
                      fill="currentColor"
                    />
                  </svg>
                </div>
                <h3 className="mb-2 text-xl font-bold dark:text-white">
                  Crosswords
                </h3>
                <p className="text-gray-500 dark:text-gray-400 font-light">
                  {/* We do not believe that rote learning is very effective and thus  */}
                  We have come up with a unique way for you to gain conceptual
                  knowledge and it is something you have to experience to
                  realise it&apos;s full potential for yourself.
                </p>
              </div>
            </div>
          </div>
        </section>
      </main>
      {/* <div className="mt-8">
        <Snippet hideCopyButton hideSymbol variant="bordered">
          <span>
            Get started by editing <Code color="primary">app/page.tsx</Code>
          </span>
        </Snippet>
      </div> */}
    </section>
  );
}
