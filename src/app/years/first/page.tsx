"use client";
import { trpc } from "@/app/_trpc/client";
import Skeleton from "react-loading-skeleton";
import Book from "@/components/Book";
import { useEffect, useState } from "react";
import { db } from "@/db";
// import { getKindeServerSession } from "@kinde-oss/kinde-auth-nextjs/server";
// import { redirect } from "next/navigation";
import { getDownloadURL, getStorage, ref } from "firebase/storage";
import firebase_app from "@/firebase/config";
import {
  Button,
  Card,
  CardBody,
  CardFooter,
  CardHeader,
  Divider,
  Link,
} from "@nextui-org/react";
import PdfRenderer from "@/components/PdfRenderer";
import { useRouter } from "next/navigation";
const Page = () => {
  // const { data: allFiles, isLoading } = trpc.getFirstYearBooks.useQuery();
  // const { getUser } = getKindeServerSession()
  // const user = getUser()

  // if (!user || !user.id) redirect('/auth-callback?origin=dashboard')
  const file = "gs://amplify-dentistry.appspot.com/Anatomy.pdf";
  const storage = getStorage(firebase_app);
  const fileRef = ref(storage, file);
  const router = useRouter();
  const [url, setUrl] = useState<any>(null);
  const getUrl = async () => {
    try {
      const getPublicUrl = await getDownloadURL(fileRef);
      console.log(getPublicUrl);
      //setUrl(getPublicUrl)
      router.push("/test-view/Anatomy");
    } catch (err) {
      console.log(err);
    }
  };
  return (
    <main className="mx-auto max-w-7xl md:p-10">
      <div className="mt-8 flex flex-col items-start justify-between gap-4 border-b border-gray-200 pb-5 sm:flex-row sm:items-center sm:gap-0">
        <h1 className="mb-3 font-bold text-5xl text-gray-900">Subjects</h1>
      </div>
      <div className="flex flex-wrap w-full">
        <Card className="max-w-[400px] bg-slate-200 min-w-[300px] rounded-lg m-2">
          <CardHeader className="flex gap-3">
            <div className="w-full">
              <p className="text-lg font-bold text-center">Anatomy</p>
              {/* <p className="text-small text-default-500">nextui.org</p> */}
            </div>
          </CardHeader>
          <Divider />
          <CardBody>
            <div className="flex w-full justify-center">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="3.33em"
                height="3em"
                viewBox="0 0 1696 1536"
              >
                <path
                  fill="currentColor"
                  d="M1671 350q40 57 18 129l-275 906q-19 64-76.5 107.5T1215 1536H292q-77 0-148.5-53.5T44 1351q-24-67-2-127q0-4 3-27t4-37q1-8-3-21.5t-3-19.5q2-11 8-21t16.5-23.5T84 1051q23-38 45-91.5t30-91.5q3-10 .5-30t-.5-28q3-11 17-28t17-23q21-36 42-92t25-90q1-9-2.5-32t.5-28q4-13 22-30.5t22-22.5q19-26 42.5-84.5T372 283q1-8-3-25.5t-2-26.5q2-8 9-18t18-23t17-21q8-12 16.5-30.5t15-35t16-36t19.5-32T504.5 12t36-11.5T588 6l-1 3q38-9 51-9h761q74 0 114 56t18 130l-274 906q-36 119-71.5 153.5T1057 1280H188q-27 0-38 15q-11 16-1 43q24 70 144 70h923q29 0 56-15.5t35-41.5l300-987q7-22 5-57q38 15 59 43m-1064 2q-4 13 2 22.5t20 9.5h608q13 0 25.5-9.5T1279 352l21-64q4-13-2-22.5t-20-9.5H670q-13 0-25.5 9.5T628 288zm-83 256q-4 13 2 22.5t20 9.5h608q13 0 25.5-9.5T1196 608l21-64q4-13-2-22.5t-20-9.5H587q-13 0-25.5 9.5T545 544z"
                />
              </svg>
            </div>
          </CardBody>
          <Divider />
          <CardFooter>
            <div className="flex w-full justify-around">
              <Button
                color="primary"
                variant="solid"
                size="lg"
                className="p-2 rounded-md"
                onClick={() => router.push("/test-view/Anatomy")}
              >
                Theory
              </Button>
              <Button
                color="primary"
                variant="solid"
                size="lg"
                className="p-2 mx-2 rounded-md"
                onClick={() => router.push("/years/Anatomy")}
              >
                Practical
              </Button>
            </div>
            {/* <Link
            isExternal
            showAnchorIcon
            href="https://github.com/nextui-org/nextui"
          >
            Visit source code on GitHub.
          </Link> */}
          </CardFooter>
        </Card>
        <Card className="max-w-[400px] bg-slate-200 min-w-[300px] rounded-lg m-2">
          <CardHeader className="flex gap-3">
            <div className="w-full">
              <p className="text-lg font-bold text-center">Physiology</p>
              {/* <p className="text-small text-default-500">nextui.org</p> */}
            </div>
          </CardHeader>
          <Divider />
          <CardBody>
            <div className="flex w-full justify-center">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="3.33em"
                height="3em"
                viewBox="0 0 1696 1536"
              >
                <path
                  fill="currentColor"
                  d="M1671 350q40 57 18 129l-275 906q-19 64-76.5 107.5T1215 1536H292q-77 0-148.5-53.5T44 1351q-24-67-2-127q0-4 3-27t4-37q1-8-3-21.5t-3-19.5q2-11 8-21t16.5-23.5T84 1051q23-38 45-91.5t30-91.5q3-10 .5-30t-.5-28q3-11 17-28t17-23q21-36 42-92t25-90q1-9-2.5-32t.5-28q4-13 22-30.5t22-22.5q19-26 42.5-84.5T372 283q1-8-3-25.5t-2-26.5q2-8 9-18t18-23t17-21q8-12 16.5-30.5t15-35t16-36t19.5-32T504.5 12t36-11.5T588 6l-1 3q38-9 51-9h761q74 0 114 56t18 130l-274 906q-36 119-71.5 153.5T1057 1280H188q-27 0-38 15q-11 16-1 43q24 70 144 70h923q29 0 56-15.5t35-41.5l300-987q7-22 5-57q38 15 59 43m-1064 2q-4 13 2 22.5t20 9.5h608q13 0 25.5-9.5T1279 352l21-64q4-13-2-22.5t-20-9.5H670q-13 0-25.5 9.5T628 288zm-83 256q-4 13 2 22.5t20 9.5h608q13 0 25.5-9.5T1196 608l21-64q4-13-2-22.5t-20-9.5H587q-13 0-25.5 9.5T545 544z"
                />
              </svg>
            </div>
          </CardBody>
          <Divider />
          <CardFooter>
            <div className="flex w-full justify-around">
              <Button
                color="primary"
                variant="solid"
                size="lg"
                className="p-2 rounded-md"
                onClick={() => router.push("/test-view/Physiology")}
              >
                Theory
              </Button>
              <Button
                color="primary"
                variant="solid"
                size="lg"
                className="p-2 mx-2 rounded-md"
                onClick={() => router.push("/test-view/Anatomy")}
              >
                Practical
              </Button>
            </div>
            {/* <Link
            isExternal
            showAnchorIcon
            href="https://github.com/nextui-org/nextui"
          >
            Visit source code on GitHub.
          </Link> */}
          </CardFooter>
        </Card>
        <Card className="max-w-[400px] min-w-[300px] bg-slate-200 rounded-lg m-2">
          <CardHeader className="flex gap-3">
            <div className="w-full">
              <p className="text-lg font-bold text-center">BioChemistry</p>
              {/* <p className="text-small text-default-500">nextui.org</p> */}
            </div>
          </CardHeader>
          <Divider />
          <CardBody>
            <div className="flex w-full justify-center">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="3.33em"
                height="3em"
                viewBox="0 0 1696 1536"
              >
                <path
                  fill="currentColor"
                  d="M1671 350q40 57 18 129l-275 906q-19 64-76.5 107.5T1215 1536H292q-77 0-148.5-53.5T44 1351q-24-67-2-127q0-4 3-27t4-37q1-8-3-21.5t-3-19.5q2-11 8-21t16.5-23.5T84 1051q23-38 45-91.5t30-91.5q3-10 .5-30t-.5-28q3-11 17-28t17-23q21-36 42-92t25-90q1-9-2.5-32t.5-28q4-13 22-30.5t22-22.5q19-26 42.5-84.5T372 283q1-8-3-25.5t-2-26.5q2-8 9-18t18-23t17-21q8-12 16.5-30.5t15-35t16-36t19.5-32T504.5 12t36-11.5T588 6l-1 3q38-9 51-9h761q74 0 114 56t18 130l-274 906q-36 119-71.5 153.5T1057 1280H188q-27 0-38 15q-11 16-1 43q24 70 144 70h923q29 0 56-15.5t35-41.5l300-987q7-22 5-57q38 15 59 43m-1064 2q-4 13 2 22.5t20 9.5h608q13 0 25.5-9.5T1279 352l21-64q4-13-2-22.5t-20-9.5H670q-13 0-25.5 9.5T628 288zm-83 256q-4 13 2 22.5t20 9.5h608q13 0 25.5-9.5T1196 608l21-64q4-13-2-22.5t-20-9.5H587q-13 0-25.5 9.5T545 544z"
                />
              </svg>
            </div>
          </CardBody>
          <Divider />
          <CardFooter>
            <div className="flex w-full justify-around">
              <Button
                color="primary"
                variant="solid"
                size="lg"
                className="p-2 rounded-md"
                onClick={() => router.push("/test-view/Biochemistry")}
              >
                Theory
              </Button>
              <Button
                color="primary"
                variant="solid"
                size="lg"
                className="p-2 mx-2 rounded-md"
                onClick={() => router.push("/test-view/Anatomy")}
              >
                Practical
              </Button>
            </div>
            {/* <Link
            isExternal
            showAnchorIcon
            href="https://github.com/nextui-org/nextui"
          >
            Visit source code on GitHub.
          </Link> */}
          </CardFooter>
        </Card>
        <Card className="max-w-[400px] bg-slate-200 min-w-[300px] rounded-lg m-2">
          <CardHeader className="flex gap-3">
            <div className="w-full">
              <p className="text-lg text-center font-bold">
                Dental Anatomy & Histology
              </p>
              {/* <p className="text-small text-default-500">nextui.org</p> */}
            </div>
          </CardHeader>
          <Divider />
          <CardBody>
            <div className="flex w-full justify-center">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="3.33em"
                height="3em"
                viewBox="0 0 1696 1536"
              >
                <path
                  fill="currentColor"
                  d="M1671 350q40 57 18 129l-275 906q-19 64-76.5 107.5T1215 1536H292q-77 0-148.5-53.5T44 1351q-24-67-2-127q0-4 3-27t4-37q1-8-3-21.5t-3-19.5q2-11 8-21t16.5-23.5T84 1051q23-38 45-91.5t30-91.5q3-10 .5-30t-.5-28q3-11 17-28t17-23q21-36 42-92t25-90q1-9-2.5-32t.5-28q4-13 22-30.5t22-22.5q19-26 42.5-84.5T372 283q1-8-3-25.5t-2-26.5q2-8 9-18t18-23t17-21q8-12 16.5-30.5t15-35t16-36t19.5-32T504.5 12t36-11.5T588 6l-1 3q38-9 51-9h761q74 0 114 56t18 130l-274 906q-36 119-71.5 153.5T1057 1280H188q-27 0-38 15q-11 16-1 43q24 70 144 70h923q29 0 56-15.5t35-41.5l300-987q7-22 5-57q38 15 59 43m-1064 2q-4 13 2 22.5t20 9.5h608q13 0 25.5-9.5T1279 352l21-64q4-13-2-22.5t-20-9.5H670q-13 0-25.5 9.5T628 288zm-83 256q-4 13 2 22.5t20 9.5h608q13 0 25.5-9.5T1196 608l21-64q4-13-2-22.5t-20-9.5H587q-13 0-25.5 9.5T545 544z"
                />
              </svg>
            </div>
          </CardBody>
          <Divider />
          <CardFooter>
            <div className="flex w-full justify-around">
              <Button
                color="primary"
                variant="solid"
                size="lg"
                className="p-2 rounded-md"
                onClick={() => router.push("/test-view/Dental Anatomy & Histology")}
              >
                Theory
              </Button>
              <Button
                color="primary"
                variant="solid"
                size="lg"
                className="p-2 mx-2 rounded-md"
                onClick={() => router.push("/test-view/Anatomy")}
              >
                Practical
              </Button>
            </div>
            {/* <Link
            isExternal
            showAnchorIcon
            href="https://github.com/nextui-org/nextui"
          >
            Visit source code on GitHub.
          </Link> */}
          </CardFooter>
        </Card>
      </div>
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
