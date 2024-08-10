"use client";
import { Icon } from "@iconify/react";
import { useState } from "react";
//import { useContext, useState } from "react";
//import { ToastContext } from "@/providers/ToastContextProvider";
//import NoticeBoard from "./NoticeBoard";
const Years = () => {
  const [loading, setLoading] = useState(false);
  //const { toast } = useContext(ToastContext);

  return (
    <main className="mx-auto max-w-7xl p-4 md:p-10">
      <div className="mt-8 flex flex-col items-start justify-between gap-4 border-b border-black pb-5 sm:flex-row sm:items-center sm:gap-0">
        <h1 className="my-3 text-center w-full text-5xl font-pSemiBold">
          Home
        </h1>
      </div>

      {loading ? (
        <div className="flex h-10 p-4 justify-center items-center">
          <h2 className="text-2xl font-pBold">Loading...</h2>
        </div>
      ) : (
        <div className="mt-16 flex flex-col items-center gap-2">
          <div className="flex p-1 w-11/12  md:w-8/12 justify-between">
            <a
              href="/home/years/first"
              className="border-b-2 border-r-2 mx-1 p-1 dark:border-white border-black w-1/2"
              //onClick={() => toast({ message: "something", type: "success" })}
            >
              <Icon
                icon="healthicons:tooth"
                className="ml-auto md:h-10 md:w-10 h-8 w-8"
              />
            </a>
            <a
              href="/home/years/second"
              className="flex w-1/2 border-b-2 border-l-2 p-1 mx-1 dark:border-white border-black"
              onClick={() => setLoading(true)}
            >
              <Icon
                className="md:h-10 md:w-10 h-8 w-8"
                icon="healthicons:tooth"
              />
              <Icon
                className="md:h-10 md:w-10 h-8 w-8"
                icon="healthicons:tooth"
              />
            </a>
          </div>
          <div className="flex p-1 w-11/12  md:w-8/12 justify-between">
            <a
              href="/home/years/fourth"
              className="border-t-2 border-r-2 p-1 flex mx-1 justify-end dark:border-white border-black w-1/2"
              onClick={() => setLoading(true)}
            >
              <Icon
                className="md:h-10 md:w-10 h-8 w-8"
                icon="healthicons:tooth"
              />
              <Icon
                className="md:h-10 md:w-10 h-8 w-8"
                icon="healthicons:tooth"
              />
              <Icon
                className="md:h-10 md:w-10 h-8 w-8"
                icon="healthicons:tooth"
              />
              <Icon
                className="md:h-10 md:w-10 h-8 w-8"
                icon="healthicons:tooth"
              />
            </a>
            <a
              href="/home/years/third"
              className="flex w-1/2 border-t-2 p-1 border-l-2 mx-1 dark:border-white border-black"
              onClick={() => setLoading(true)}
            >
              <Icon
                className="md:h-10 md:w-10 h-8 w-8"
                icon="healthicons:tooth"
              />
              <Icon
                className="md:h-10 md:w-10 h-8 w-8"
                icon="healthicons:tooth"
              />
              <Icon
                className="md:h-10 md:w-10 h-8 w-8"
                icon="healthicons:tooth"
              />
            </a>
          </div>
          <br />
          {/* <div className="w-full">
            <NoticeBoard />
          </div> */}
        </div>
      )}
    </main>
  );
};

export default Years;
