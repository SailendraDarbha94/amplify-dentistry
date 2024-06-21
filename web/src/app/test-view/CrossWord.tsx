import app from "@/lib/firebase";
import { getAuth, onAuthStateChanged } from "firebase/auth";
import { getDatabase, onValue, ref, set, update } from "firebase/database";
import React, { useEffect, useState } from "react";

function Crossword({ crossWordName, finalScore }: any) {
  const initialGrid = [
    [null, null, "R", "A", "M", "U", "S", null, null, null, null],
    [null, null, "E", null, "E", null, null, null, null, null, null],
    [null, "A", "D", "E", "N", "O", "I", "D", "S", null, null],
    [null, "N", null, null, "T", "C", null, null, null, null, null],
    [null, "A", null, "V", "A", "C", "U", "O", "L", "E", null],
    [null, "E", null, "A", "L", "I", null, null, null, null, null],
    [null, "M", null, "G", null, "P", null, null, null, null, null],
    [null, "I", null, "U", null, "I", null, null, null, null, null],
    ["M", "A", "S", "S", "E", "T", "E", "R", null, null, null],
    [null, null, null, null, null, "A", null, null, null, null, null],
    [null, null, null, null, null, "L", null, null, null, null, null],
  ];

  const [crosswordCompleted, setCrossWordCompleted] = useState<boolean>(false);
  const isCrosswordCompleted = async () => {
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
    } catch (err) {
      console.log(JSON.stringify(err));
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

  const [grid, setGrid] = useState(createInitialState(initialGrid));
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
            score: 46,
          }
        );
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
    <div className="bg-red-300 flex flex-wrap justify-center items-center">
      <div className="w-full md:w-1/2">
        <div>
          <p className="text-xl inline-block font-pBold">Across</p>
          <ul className="list-decimal list-inside font-pMedium text-md">
            <li>
              the part of jaw bone that supports muscles and teeth(5 letters)
            </li>
            <li>another term for tonsils(8 letters)</li>
            <li>a cell organelle used for storage(7 letters)</li>
            <li>a primary masticatory muscle(8 letters)</li>
          </ul>
        </div>
        <div>
          <p className="text-xl inline-block font-pBold">Down</p>
          <ul className="list-decimal list-inside font-pMedium text-md">
            <li>a chronic lack of haemoglobin(7 letters)</li>
            <li>the color of inflamed gingiva(3 letters)</li>
            <li>the 10th cranial nerve(5 letters)</li>
            <li>a foramen near the chin(6 letters)</li>
            <li>a bone that forms the base of skull(9 letters)</li>
          </ul>
        </div>
        {scoreLock ? (
          <button className="bg-blue-500 p-2 rounded-md" onClick={saveScore}>
            save
          </button>
        ) : null}
      </div>
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
    </div>
  );
}

export default Crossword;
