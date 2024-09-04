"use client";
import { useState } from "react";
import QuizItem from "./quizItem";

const Quiz = ({
  counter,
  scorer,
  quizQuestions,
  increment,
  setCounter,
}: {
  counter: any;
  scorer: any;
  setCounter: any;
  quizQuestions: any[];
  increment: number;
}) => {
  return (
    <main>
      <div>
        {quizQuestions.map((val: any) => {
          if (val.id === counter) {
            return (
              <QuizItem
                key={val.id}
                answer={val.answer}
                setCounter={setCounter}
                counter={counter}
                id={val.id}
                increment={increment}
                options={val.options}
                question={val.question}
                scorer={scorer}
              />
            );
          } else {
            return null;
          }
        })}
      </div>
    </main>
  );
};

export default Quiz;
