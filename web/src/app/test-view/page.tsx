"use client";
import styles from "./styles.module.css";
import bgImage from "../../../public/images/background.webp";
import Crossword from "../../components/CrossWord";

import {
  firstGrid,
  hintsAcross,
  hintsDown,
} from "@/constants/crosswords";
import Chatter from "@/components/Chatter";

const Page = () => {
  return (
    <main>
      <div
        style={{
          backgroundImage: `url(${bgImage.src})`,
          position: "fixed",
          minHeight: "100vh",
          top: "0",
          left: "0",
          width: "100%",
          zIndex: "-1",
          backgroundPosition: "center",
          backgroundSize: "cover",
          backgroundAttachment: "fixed",
          overflow: "hidden",
        }}
      />
      <div>
        <header className="font-pBold p-4">
          <h1 className={styles.title}>First Year</h1>
        </header>
      </div>
      <Crossword
        crosswordGrid={firstGrid}
        crossWordName="firstCrossword"
        finalScore={46}
        hintsAcross={hintsAcross}
        hintsDown={hintsDown}
      />

      <br />
      <br />
      <Chatter />
    </main>
  );
};

export default Page;
