"use client";

import {
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardContent,
  CardFooter,
} from "./ui/card";

interface Props {
  title: string;
  notice: string;
  author: string;
}

const Notice = ({ title, notice, author }: Props) => {
  return (
    <Card className="text-center mx-2 bg-yellow-300 border-yellow-300 text-sm min-w-sm max-h-80">
      <CardHeader>
        <CardTitle className="text-md font-bold">{title}</CardTitle>
        <CardDescription>
          <hr className="w-full border-green-800" />
        </CardDescription>
      </CardHeader>
      <CardContent className="">
        <p className="">{notice}</p>
      </CardContent>
      <CardFooter className="">
        <p className="ml-auto text-sm">Posted By {author}</p>
      </CardFooter>
    </Card>
  );
};

export default Notice;
