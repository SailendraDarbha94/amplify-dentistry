"use client";
import { MarksContext } from "@/app/years/[subject]/page";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { useContext, useEffect, useState } from "react";

const Grade = () => {
  const marks = useContext(MarksContext)
  const [grade, setGrade] = useState<string>("N/A");
  const setGrades = async () => {
    switch (marks) {
      case 2:
        setGrade("F");
        break;
      case 4:
        setGrade("E");
        break;
      case 8:
        setGrade("D");
        break;
      case 12:
        setGrade("C");
        break;
      case 16:
        setGrade("B");
        break;
      case 18:
        setGrade("A");
        break;
    }
    return null;
  };

  useEffect(() => {
    setGrades()
  }, [marks])

  return (
    <div className="sticky top-0 z-20  rounded-lg p-2 text-black mx-1 md:mx-8">
      {/* <h2 className="text-xl p-2">Grade : {marks}</h2>
      <h2 className="text-xl p-2">Total Marks : {marks}</h2> */}
      <Card className="text center bg-blue-300 shadow-black shadow-sm m-2">
        <CardHeader>
          {/* <CardTitle className="text-lg">Report</CardTitle>
          <CardDescription>----------</CardDescription> */}
        </CardHeader>
        <CardContent className="flex justify-around">
          <p className="font-semibold">Marks : </p>
          <p className="font-semibold">{marks}</p>
        </CardContent>
        <CardFooter className="flex justify-around">
          <p className="font-semibold">Grade :</p>
          <p className="font-semibold">{grade}</p>
        </CardFooter>
      </Card>
    </div>
  );
};

export default Grade;
