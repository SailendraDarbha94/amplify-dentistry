"use client";
import { trpc } from "@/app/_trpc/client";
import Skeleton from "react-loading-skeleton";
import Book from "@/components/Book";

const Page = () => {
  const { data: allFiles, isLoading } = trpc.getSecondYearBooks.useQuery();
  return (
    <main className="mx-auto max-w-7xl md:p-10">
      <div className="mt-8 flex flex-col items-start justify-between gap-4 border-b border-gray-200 pb-5 sm:flex-row sm:items-center sm:gap-0">
        <h1 className="mb-3 font-bold text-5xl text-gray-900">Subjects</h1>
      </div>
      {/* display all user files */}
      {allFiles && allFiles?.length !== 0 ? (
        <ul className="mt-8 grid grid-cols-1 gap-6 divide-y divide-zinc-200 md:grid-cols-2 lg:grid-cols-3">
          {allFiles
            .sort(
              (a, b) =>
                new Date(b.createdAt).getTime() -
                new Date(a.createdAt).getTime()
            )
            .map((file) => (
              <Book {...file} />
            ))}
        </ul>
      ) : isLoading ? (
        <Skeleton height={100} className="my-2" count={3} />
      ) : null}
    </main>
  );
};

export default Page;
