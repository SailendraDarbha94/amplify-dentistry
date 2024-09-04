// "use client";

// import Quiz from "@/components/quiz";
// import { Button } from "@nextui-org/button";
// import { useState } from "react";

// const TestItem = ({ params, increaseParams, item }: any) => {
//   const increaser = () => {
//     increaseParams((prev: number) => {
//       return prev + 1;
//     });
//   };

//   return (
//     <div>
//       <p>{params}</p>
//       <p>{JSON.stringify(item)}</p>
//       <Button color="danger" variant="flat" onPress={increaser}>
//         Increase
//       </Button>
//     </div>
//   );
// };

// const Page = () => {
//   const itemsArr = [
//     {
//       id: 1,
//       name: "sai",
//     },
//     {
//       id: 2,
//       name: "sail",
//     },
//     {
//       id: 3,
//       name: "sailen",
//     },
//     {
//       id: 4,
//       name: "sailendra",
//     },
//   ];

//   const [incre, setIncre] = useState<number>(0);

//   return (
//     <div>
//       <p>Test View </p>
//       <Quiz quizQuestions={itemsArr} increment={5} />
//     </div>
//   );
// };

// export default Page;
