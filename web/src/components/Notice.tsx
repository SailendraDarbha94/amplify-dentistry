"use client";

import {
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardContent,
  CardFooter,
} from "./ui/Card";

interface Props {
  title: string;
  notice: string;
  author: string;
}

const Notice = ({ title, notice, author }: Props) => {
  return (
    <Card className="text-center mx-2 my-2 bg-yellow-300 border-yellow-300 text-sm min-w-sm max-h-80">
      <CardHeader>
        <CardTitle className="text-xl text-black font-pSemiBold">{title}</CardTitle>
        {/* <CardDescription>
        </CardDescription> */}
      </CardHeader>
      <hr className=" border-black mb-4" />
      <CardContent className="">
        <p className="font-pMedium text-black">{notice}</p>
      </CardContent>
      <CardFooter className="">
        <p className="ml-auto text-sm font-pLight text-black">Posted By {author}</p>
      </CardFooter>
    </Card>
  );
};

export default Notice;