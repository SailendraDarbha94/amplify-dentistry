"use client";
import styles from "./styles.module.css";
import bgImage from "../../../public/images/background.webp";
import Crossword from "./CrossWord";
const Page = () => {
  return (
    <div className={styles.dashboard}>
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
      <Crossword crossWordName="firstCrossword" finalScore={46} />
    </div>
  );
};

export default Page;
