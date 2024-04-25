"use client";

import PdfRenderer from "@/components/PdfRenderer";
import SimpleChatter from "@/components/SimpleChatter";
import ChatWrapper from "@/components/chat/ChatWrapper";
import firebase_app from "@/firebase/config";
import { getDownloadURL, getStorage, ref } from "firebase/storage";
import { useParams } from "next/navigation";
import { useEffect, useState } from "react";

const Page = () => {
  const [url, setUrl] = useState<string>("");
  const param = useParams();
  const path: string = "gs://amplify-dentistry.appspot.com/";
  const storage = getStorage(firebase_app);
  const fileRef = ref(storage, path + param.theory + ".pdf");
  const urlGetter = async () => {
    try {
      const url = await getDownloadURL(fileRef);
      await setUrl(url);
    } catch (err) {
      console.log(err);
    }
  };

  useEffect(() => {
    urlGetter();
  }, []);

  return (
    <div className="w-full min-h-screen py-10">
      {/* <h1 className="mb-3 font-bold text-5xl text-gray-900 text-center">
        {param.theory}
      </h1> */}
      <div className="flex w-full">
        <div className="w-full md:w-1/2">
          {url ? <PdfRenderer url={url} /> : null}
        </div>
        <div className="w-full md:w-1/2">
            <SimpleChatter />
        </div>
      </div>
    </div>
  );
};

export default Page;
