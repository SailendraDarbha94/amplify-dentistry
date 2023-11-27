"use client";

import { format } from "date-fns";
import Link from "next/link";
import { Button } from "./ui/button";
import { useEffect, useState } from "react";
import Image from "next/image";
import { Loader2 } from "lucide-react";

const Book = ({ id, name }: { id: string; name: string }) => {
  const [loading, setLoading] = useState(false);
  // useEffect(() => {
  //   console.log("triggering once?")
  // })
  return (
    <li
    key={id}
    className="col-span-1 h-96 mx-auto max-h-96 max-w-xs divide-y divide-gray-200 rounded-lg bg-white shadow transition hover:shadow-lg md:mx-0"
  >
    <Image
      src={`/subjects/${name.split(".")[0]}.png`}
      //fill
      width={200}
      height={200}
      alt="book"
      className="h-56 w-full mx-auto rounded-t-md"
    />
    <h3 className="text-lg pt-4 flex flex-col justify-center items-center font-large font-bold text-zinc-900 break-normal mx-auto">
      {/* TODO: figure out a better way of handling book names */}
      {name.split(".")[0]}
    </h3>

    <div className="py-4 px-4 mt-4 flex w-full items-center justify-between space-x-6">
      {/* <div className="h-10 w-10 flex-shrink-0 rounded-full bg-gradient-to-r from-cyan-500 to-blue-500" /> */}

      <div className="flex-1 truncate">
        {loading ? (
          <Loader2 className="h-8 w-8 animate-spin text-zinc-800 mx-auto" />
        ) : (
          <div className="flex justify-around items-center space-x-3">
            <Link
              href={`/dashboard/${id}`}
              className="flex flex-col gap-2"
            >
              <Button
                onClick={() => {
                  setLoading(true);
                }}
                size="lg"
                className="w-full"
                variant="default"
              >
                Theory
              </Button>
            </Link>
            <Link
              href={`/years/${name}`}
              className="flex flex-col gap-2"
            >
              <Button
                //disabled
                onClick={() => {
                  setLoading(true);
                }}
                size="lg"
                className="w-full"
                variant="default"
              >
                MCQs
              </Button>
            </Link>
          </div>
        )}
      </div>
    </div>
  </li>
  );
};

export default Book;
