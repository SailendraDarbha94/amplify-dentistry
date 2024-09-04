"use client";

import { notices } from "@/config/notices";
import { useEffect, useState } from "react";

const NoticeBoard = ({ year }: { year: string | string[] }) => {
  const [loading, setLoading] = useState<boolean>(false);

  useEffect(() => {
    console.log(year);
  }, []);

  return (
    <div className="dark:bg-slate-900 w-full font-pMedium border-2 mx-auto shadow-lg shadow-slate-300 dark:shadow-slate-800 border-black dark:border-slate-500 bg-transparent rounded-lg">
      <h2 className="font-pExtraBold text-center text-2xl text-white bg-black">
        NoticeBoard
      </h2>
      <hr className="w-full border-black dark:border-slate-500" />
      <div className="flex justify-evenly overflow-scroll">
        {loading ? (
          <div className="flex h-10 p-4 justify-center items-center">
            <h2 className="text-2xl font-pBold">Loading...</h2>
          </div>
        ) : (
          notices?.map((notice: any) => {
            return (
              <div
                key={notice.id}
                className="max-w-sm border-2 dark:border-white border-black m-2 rounded-xl"
              >
                <h1 className="text-center text-2xl border-b-2 dark:border-white border-black">
                  {notice.title}
                </h1>
                <p className="text-lg p-2">{notice.notice}</p>
                <p className="p-2">Posted By: {notice.author}</p>
              </div>
            );
          })
        )}
      </div>
    </div>
  );
};

export default NoticeBoard;
