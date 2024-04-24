"use client";
import { trpc } from "@/app/_trpc/client";
import Skeleton from "react-loading-skeleton";
import Book from "@/components/Book";
import { useEffect, useState } from "react";
import { db } from "@/db";
// import { getKindeServerSession } from "@kinde-oss/kinde-auth-nextjs/server";
// import { redirect } from "next/navigation";
import { getDownloadURL, getStorage, ref } from 'firebase/storage'
import firebase_app from "@/firebase/config";
import { Button } from "@nextui-org/react";
import PdfRenderer from "@/components/PdfRenderer";
const Page = () => {
  // const { data: allFiles, isLoading } = trpc.getFirstYearBooks.useQuery();
  // const { getUser } = getKindeServerSession()
  // const user = getUser()

  // if (!user || !user.id) redirect('/auth-callback?origin=dashboard')
  const file = "gs://amplify-dentistry.appspot.com/Anatomy.pdf"
  const storage = getStorage(firebase_app)
  const fileRef = ref(storage, file)
  const [url, setUrl] = useState<any>(null)
  const getUrl = async () => {
    try {
      const getPublicUrl = await getDownloadURL(fileRef);
      console.log(getPublicUrl)
      setUrl(getPublicUrl)
    } catch (err) {
      console.log(err)
    }
    
  }
  return (
    <main className="mx-auto max-w-7xl md:p-10">
      <div className="mt-8 flex flex-col items-start justify-between gap-4 border-b border-gray-200 pb-5 sm:flex-row sm:items-center sm:gap-0">
        <h1 className="mb-3 font-bold text-5xl text-gray-900">Subjects</h1>
      </div>
      <Button color="primary" size="md" className="rounded-md p-2 m-2" onClick={getUrl}>
        Click me
      </Button>
      {url && <PdfRenderer url={url} />}
      {/* display all user files */}
      {/* {allFiles && allFiles?.length !== 0 ? (
        <ul className="mt-8 grid grid-cols-1 gap-6 divide-y divide-zinc-200 md:grid-cols-2 lg:grid-cols-3">
          {allFiles
            .sort(
              (a, b) =>
                new Date(b.createdAt).getTime() -
                new Date(a.createdAt).getTime()
            )
            .map((file) => (
              <Book key={file.id} id={file.id} name={file.name} />
            ))}
        </ul>
      )
       : isLoading ? (
        <Skeleton height={100} className="my-2" count={3} />
      ) 
      : null} */}
    </main>
  );
};

export default Page;
