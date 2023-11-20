"use client";
import { trpc } from "@/app/_trpc/client";
import { Icon } from "@iconify/react";
import { Loader2 } from "lucide-react";
import { useState } from "react";
import Notice from "./Notice";
const Years = () => {
  const [loading, setLoading] = useState(false);

  const { data: notices, isLoading } = trpc.getAllNotices.useQuery();

  return (
    <main className="mx-auto max-w-7xl md:p-10">
      <div className="mt-8 flex flex-col items-start justify-between gap-4 border-b border-gray-200 pb-5 sm:flex-row sm:items-center sm:gap-0">
        <h1 className="mb-3 font-bold text-5xl text-gray-900">
          Home
          {/* <hr />
          <span className="text-sm block m-2 p-2">Choose an Year</span> */}
        </h1>
      </div>

      {loading ? (
        <div className="flex h-10 p-4 justify-center items-center">
          <Loader2 className="h-8 w-8 animate-spin text-zinc-800" />
        </div>
      ) : (
        <div className="mt-16 flex flex-col items-center gap-2">
          <div className="flex p-1 w-11/12  md:w-8/12 justify-between">
            <a
              href="/years/first"
              className="border-b-2 border-r-2 mx-1 p-1 border-black w-1/2"
              onClick={() => setLoading(true)}
            >
              <Icon
                icon="healthicons:tooth"
                className="ml-auto md:h-10 md:w-10 h-8 w-8"
              />
            </a>
            <a
              href="/years/second"
              className="flex w-1/2 border-b-2 border-l-2 p-1 mx-1 border-black"
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
              href="/years/fourth"
              className="border-t-2 border-r-2 p-1 flex mx-1 justify-end border-black w-1/2"
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
              href="/years/third"
              className="flex w-1/2 border-t-2 p-1 border-l-2 mx-1 border-black"
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
          <div className=" w-11/12 border-2 bg-green-700 rounded-lg  border-green-700">
            <h2 className="font-bold text-center text-2xl text-white">NoticeBoard</h2>
            <hr className="w-full border-black" />
            <div className="flex justify-evenly">
              {isLoading ? (
                <div className="flex h-10 p-4 justify-center items-center">
                  <Loader2 className="h-8 w-8 animate-spin text-zinc-800" />
                </div>
              ) : (
                notices?.map((notice: any) => {
                  return <Notice {...notice} />;
                })
              )}
            </div>
          </div>
        </div>
      )}
    </main>
  );
};

export default Years;
