"use client";
import { Icon } from "@iconify/react";
import { Loader2 } from "lucide-react";
import { useState } from "react";
const Years = () => {
  const [loading, setLoading] = useState(false);
  return (
    <main className="mx-auto max-w-7xl md:p-10">
      <div className="mt-8 flex flex-col items-start justify-between gap-4 border-b border-gray-200 pb-5 sm:flex-row sm:items-center sm:gap-0">
        <h1 className="mb-3 font-bold text-5xl text-gray-900">
          Home
          {/* <hr />
          <span className="text-sm block m-2 p-2">Choose an Year</span> */}
        </h1>
      </div>

      <div className="mt-16 flex flex-col items-center gap-2">
        <div className="flex p-1 w-11/12  md:w-8/12 justify-between">
          <a
            href="/years/first"
            className="border-b-2 border-r-2 mx-1 p-1 border-black w-1/2"
            onClick={() => setLoading(true)}
          >
            {loading ? (
              <Loader2 className="h-8 w-8 animate-spin text-zinc-800" />
            ) : (
              <Icon
                icon="healthicons:tooth"
                className="ml-auto md:h-10 md:w-10 h-8 w-8"
              />
            )}
          </a>
          <a
            href="/years/second"
            className="flex w-1/2 border-b-2 border-l-2 p-1 mx-1 border-black"
            onClick={() => setLoading(true)}
          >
            {loading ? (
              <Loader2 className="h-8 w-8 animate-spin text-zinc-800" />
            ) : (
              <>
                <Icon
                  className="md:h-10 md:w-10 h-8 w-8"
                  icon="healthicons:tooth"
                />
                <Icon
                  className="md:h-10 md:w-10 h-8 w-8"
                  icon="healthicons:tooth"
                />
              </>
            )}
          </a>
        </div>
        <div className="flex p-1 w-11/12  md:w-8/12 justify-between">
          <a
            href="/years/fourth"
            className="border-t-2 border-r-2 p-1 flex mx-1 justify-end border-black w-1/2"
            onClick={() => setLoading(true)}
          >
            {loading ? (
              <Loader2 className="h-8 w-8 animate-spin text-zinc-800" />
            ) : (
              <>
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
              </>
            )}
          </a>
          <a
            href="/years/third"
            className="flex w-1/2 border-t-2 p-1 border-l-2 mx-1 border-black"
            onClick={() => setLoading(true)}
          >
            {loading ? (
              <Loader2 className="h-8 w-8 animate-spin text-zinc-800" />
            ) : (
              <>
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
              </>
            )}
          </a>
        </div>
      </div>
    </main>
  );
};

export default Years;
