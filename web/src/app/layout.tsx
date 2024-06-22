import type { Metadata } from "next";
import "./globals.css";
import ToastContextProvider from "@/providers/ToastContextProvider";
import NavBar from "@/components/NavBar";

export const metadata: Metadata = {
  title: "Amplify Dentistry",
  description: "A learning platform aimed at empowering Dental Students",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>
        <ToastContextProvider>
          <div className="z-0 sticky top-2 right-0">
            <NavBar />
          </div>
          {children}
        </ToastContextProvider>
      </body>
    </html>
  );
}
