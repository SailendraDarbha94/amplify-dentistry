"use client";
import Crossword from "@/components/CrossWord";
import bgImage from "../../../../../public/images/background.webp";
import secondBgImage from "../../../../../public/images/secondBackground.webp";
import styles from "../styles.module.css";
import { useParams } from "next/navigation";
import {
  firstGrid,
  hintsAcross,
  hintsDown,
  secondGrid,
  secondHintsDown,
  secondHintsAcross,
} from "@/constants/crosswords";
import Chatter from "@/components/Chatter";
const Page = () => {
  const { slug } = useParams();

  const yearWiseCrossWord = () => {
    switch (slug) {
      case "first":
        return (
          <Crossword
            crosswordGrid={firstGrid}
            crossWordName="firstCrossword"
            finalScore={46}
            hintsAcross={hintsAcross}
            hintsDown={hintsDown}
          />
        );
      case "second":
        return (
          <Crossword
            crosswordGrid={secondGrid}
            crossWordName="secondCrossword"
            finalScore={55}
            hintsAcross={secondHintsAcross}
            hintsDown={secondHintsDown}
          />
        );
    }
  };

  const yearWiseBackground = () => {
    switch (slug) {
      case "first":
        return (
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
        );
      case "second":
        return (
          <div
            style={{
              backgroundImage: `url(${secondBgImage.src})`,
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
        );
    }
  };

  return (
    <main>
      {yearWiseBackground()}
      <div>
        <header className="font-pBold p-4">
          <h1 className={styles.title}>{slug} year</h1>
        </header>
      </div>
      {yearWiseCrossWord()}
      <br />
      <br />
      <Chatter />
    </main>
  );
};
export default Page;