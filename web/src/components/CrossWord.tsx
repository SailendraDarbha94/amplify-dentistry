import app from "@/lib/firebase";
import { ToastContext } from "@/providers/ToastContextProvider";
import { getAuth, onAuthStateChanged } from "firebase/auth";
import { getDatabase, onValue, ref, set, update } from "firebase/database";
import React, { useContext, useEffect, useState } from "react";

function Crossword({
  crossWordName,
  finalScore,
  crosswordGrid,
  hintsAcross,
  hintsDown,
}: any) {
  const { toast } = useContext(ToastContext);
  const [crosswordCompleted, setCrossWordCompleted] = useState<boolean>(false);
  const [loading, setLoading] = useState<boolean>(false);
  const isCrosswordCompleted = async () => {
    setLoading(true);
    try {
      const auth = await getAuth(app);
      let userDetails: any;
      onAuthStateChanged(auth, async (user) => {
        userDetails = await user;

        const id = await userDetails.uid;
        const db = getDatabase(app);
        const crossWordRef = ref(
          db,
          "/users/" + id + "/crossWords/" + crossWordName
        );

        onValue(crossWordRef, (snapshot) => {
          if (snapshot.exists()) {
            const data = snapshot.val();
            if (data.completed) {
              setCrossWordCompleted(true);
            }
          } else {
            set(crossWordRef, {
              completed: false,
              score: finalScore,
            });
          }
        });
      });
      setLoading(false);
    } catch (err) {
      console.log(JSON.stringify(err));
      setLoading(false);
    }
  };

  useEffect(() => {
    isCrosswordCompleted();
  }, []);

  const createInitialState = (grid: any) =>
    grid.map((row: any) =>
      row.map((cell: any) => ({
        letter: cell,
        content: "",
        disabled: false,
      }))
    );

  const [grid, setGrid] = useState(createInitialState(crosswordGrid));
  const [score, setScore] = useState(0);
  const [scoreLock, setScoreLock] = useState<boolean>(false);
  const scorePlus = async () => {
    setScore((prevScore) => prevScore + 1);
  };

  const saveScore = async () => {
    try {
      const auth = getAuth(app);
      await onAuthStateChanged(auth, async (user) => {
        const db = getDatabase(app);
        await update(
          ref(db, `/users/${user?.uid}/crossWords/${crossWordName}`),
          {
            completed: true,
            score: finalScore,
          }
        );
        toast({
          message: "Crossword Saved, Congratulations!",
          type: "success",
        })
      });
    } catch (err) {
      JSON.stringify(err);
    }
  };

  useEffect(() => {
    if (score === finalScore) {
      setScoreLock(true);
    }
  }, [score]);

  const handleCellChange = async (i: any, j: any, value: any) => {
    const newGrid = [...grid];
    newGrid[i][j].content = value.toUpperCase();
    if (newGrid[i][j].letter === value.toUpperCase()) {
      newGrid[i][j].disabled = true;
      await scorePlus();
    }
    setGrid(newGrid);
  };

  const Cell = ({ cell, onChange, completed }: any) => {
    const { letter, content, disabled } = cell;
    const handleChange = (e: any) => {
      onChange(e.target.value);
    };

    return (
      <>
        {letter ? (
          <div
            className={`${
              content === letter ? "bg-emerald-400" : "bg-purple-100"
            } h-10 w-10 border-2 border-black rounded-md flex justify-center text-lg font-pBold items-center text-black`}
          >
            {completed ? (
              <span className="">{letter}</span>
            ) : (
              <input
                disabled={disabled}
                className="focus:outline-none w-6 h-full bg-inherit text-center"
                value={content}
                maxLength={1}
                onChange={handleChange}
                required={true}
                type="text"
              />
            )}
          </div>
        ) : (
          <span className="flex rounded-md justify-center items-center w-10 text-black font-pBold text-lg h-10 border-2 border-black bg-slate-600">
            {null}
          </span>
        )}
      </>
    );
  };

  return (
    <div className="bg-secondary dark:bg-primary flex flex-wrap justify-center mx-4 rounded-xl items-center p-4">
      <div className="w-full md:w-1/2">
        <div className="p-2">
          <p className="text-xl inline-block font-pBold my-2">Across</p>
          <ul className="list-decimal list-inside font-pMedium text-md">
            {hintsAcross.map((hint: string, index: any) => {
              return <li key={index}>{hint}</li>;
            })}
          </ul>
        </div>
        <div className="p-2">
          <p className="text-xl inline-block font-pBold my-2">Down</p>
          <ul className="list-decimal list-inside font-pMedium text-md">
            {hintsDown.map((hint: string, index: any) => {
              return <li key={index}>{hint}</li>;
            })}
          </ul>
        </div>
        {scoreLock ? (
          <button
            className="block mt-4 border-2 min-w-40 border-black mx-auto p-2 font-pBold text-xl rounded-md"
            onClick={saveScore}
          >
            SAVE
          </button>
        ) : null}
      </div>
      {loading ? (
        <div
          role="status"
          className="flex min-h-96 max-h-full justify-center items-center">
          <svg
            aria-hidden="true"
            className="w-8 h-8 text-gray-200 animate-spin dark:text-gray-600 fill-blue-600"
            viewBox="0 0 100 101"
            fill="none"
            xmlns="http://www.w3.org/2000/svg"
          >
            <path
              d="M100 50.5908C100 78.2051 77.6142 100.591 50 100.591C22.3858 100.591 0 78.2051 0 50.5908C0 22.9766 22.3858 0.59082 50 0.59082C77.6142 0.59082 100 22.9766 100 50.5908ZM9.08144 50.5908C9.08144 73.1895 27.4013 91.5094 50 91.5094C72.5987 91.5094 90.9186 73.1895 90.9186 50.5908C90.9186 27.9921 72.5987 9.67226 50 9.67226C27.4013 9.67226 9.08144 27.9921 9.08144 50.5908Z"
              fill="currentColor"
            />
            <path
              d="M93.9676 39.0409C96.393 38.4038 97.8624 35.9116 97.0079 33.5539C95.2932 28.8227 92.871 24.3692 89.8167 20.348C85.8452 15.1192 80.8826 10.7238 75.2124 7.41289C69.5422 4.10194 63.2754 1.94025 56.7698 1.05124C51.7666 0.367541 46.6976 0.446843 41.7345 1.27873C39.2613 1.69328 37.813 4.19778 38.4501 6.62326C39.0873 9.04874 41.5694 10.4717 44.0505 10.1071C47.8511 9.54855 51.7191 9.52689 55.5402 10.0491C60.8642 10.7766 65.9928 12.5457 70.6331 15.2552C75.2735 17.9648 79.3347 21.5619 82.5849 25.841C84.9175 28.9121 86.7997 32.2913 88.1811 35.8758C89.083 38.2158 91.5421 39.6781 93.9676 39.0409Z"
              fill="currentFill"
            />
          </svg>
          <span className="sr-only">Loading...</span>
        </div>
      ) : (
        <div className="w-full md:w-1/2">
          {grid.map((row: any, i: any) => (
            <div
              className="w-fit mx-auto flex justify-center items-center"
              key={`${i}`}
            >
              {row.map((cell: any, j: any) => (
                <Cell
                  completed={crosswordCompleted}
                  key={`${i}-${j}`}
                  cell={cell}
                  onChange={(value: any) => handleCellChange(i, j, value)}
                />
              ))}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

export default Crossword;
